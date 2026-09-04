import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies whether the currently installed native TTS engine can actually
/// synthesize a short utterance for a delivery language on this device.
///
/// Android TTS capability reporting varies by engine/OEM. A successful
/// synthesis followed by the native completion callback is treated as the
/// authoritative capability signal. The result is cached per language for
/// the current app installation and can be invalidated after voice data is
/// installed or the engine configuration changes.
class TtsCapabilityService {
  TtsCapabilityService._();
  static final TtsCapabilityService instance = TtsCapabilityService._();

  static const _prefsPrefix = 'tts_native_capability_v1_';
  static const _probeTimeout = Duration(seconds: 4);

  final Map<String, bool> _memoryCache = {};
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async =>
      _prefs ??= await SharedPreferences.getInstance();

  List<String> candidatesFor(String deliveryLanguage) {
    switch (deliveryLanguage) {
      case 'urdu':
        return const ['ur-PK', 'ur-IN'];
      default:
        return const ['en-US', 'en-GB', 'en-IN'];
    }
  }

  Future<bool> isNativeReliable(
    FlutterTts native,
    String deliveryLanguage,
  ) async {
    final memory = _memoryCache[deliveryLanguage];
    if (memory != null) return memory;

    final prefs = await _prefsInstance;
    final key = '$_prefsPrefix$deliveryLanguage';
    final cached = prefs.getBool(key);
    if (cached != null) {
      _memoryCache[deliveryLanguage] = cached;
      return cached;
    }

    final result = await _probe(native, deliveryLanguage);
    _memoryCache[deliveryLanguage] = result;
    unawaited(prefs.setBool(key, result));
    return result;
  }

  Future<void> invalidate(String deliveryLanguage) async {
    _memoryCache.remove(deliveryLanguage);
    final prefs = await _prefsInstance;
    await prefs.remove('$_prefsPrefix$deliveryLanguage');
  }

  Future<bool> _probe(FlutterTts native, String deliveryLanguage) async {
    for (final locale in candidatesFor(deliveryLanguage)) {
      try {
        if (await _trySpeakLocale(native, locale)) return true;
      } catch (e) {
        debugPrint('TTS capability probe failed for $locale: $e');
      }
    }
    return false;
  }

  Future<bool> _trySpeakLocale(FlutterTts native, String locale) async {
    // Do not gate the probe on isLanguageAvailable(). Several engines/OEMs
    // report false even when the selected locale can still synthesize audio.
    try {
      await native.setLanguage(locale);
    } catch (e) {
      debugPrint('TTS setLanguage failed for $locale: $e');
      return false;
    }

    final completer = Completer<bool>();
    native.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete(true);
    });
    native.setErrorHandler((msg) {
      debugPrint('TTS probe engine error for $locale: $msg');
      if (!completer.isCompleted) completer.complete(false);
    });

    try {
      final result = await native.speak('.');
      if (result != 1) return false;
      return await completer.future.timeout(
        _probeTimeout,
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }
}
