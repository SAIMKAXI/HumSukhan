import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device-native speech capability registry shared by STT and TTS.
///
/// Native speech engines are device configuration, not app configuration.
/// STT capability is determined from the recognizer's installed locale list;
/// silently probing recognition would require opening the microphone and is
/// therefore intentionally not done. TTS capability is verified with a real
/// short synthesis and completion callback.
///
/// Persisted results are scoped by platform + OS version. A negative result is
/// cheap to recheck on resume so newly installed language packs are discovered
/// without making every launch pay the probe cost.
class SpeechCapability {
  SpeechCapability._();
  static final SpeechCapability instance = SpeechCapability._();

  static const _prefsPrefix = 'speech_capability_v2_';
  static const _ttsProbeTimeout = Duration(seconds: 4);

  final Map<String, bool> _memoryCache = <String, bool>{};
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async =>
      _prefs ??= await SharedPreferences.getInstance();

  String get _scope =>
      '${Platform.operatingSystem}_${Platform.operatingSystemVersion}';

  String _key(String capability) => '$_prefsPrefix$_scope|$capability';

  String _normalizeLocale(String locale) =>
      locale.trim().toLowerCase().replaceAll('_', '-').split('-').first;

  bool _matchesLanguage(String locale, String language) {
    return _normalizeLocale(locale) == _normalizeLocale(language);
  }

  List<String> _localeIds(List<dynamic> locales) {
    final ids = <String>[];
    for (final locale in locales) {
      final id = locale is String
          ? locale
          : (locale as dynamic).localeId?.toString() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  Future<bool> _readOrProbe(
    String capability,
    Future<bool> Function() probe, {
    bool recheckNegative = false,
  }) async {
    final memory = _memoryCache[capability];
    if (memory == true || (memory == false && !recheckNegative)) return memory;

    final prefs = await _prefsInstance;
    final cached = prefs.getBool(_key(capability));
    if (cached == true || (cached == false && !recheckNegative)) {
      _memoryCache[capability] = cached!;
      return cached;
    }

    final result = await probe();
    _memoryCache[capability] = result;
    unawaited(prefs.setBool(_key(capability), result));
    return result;
  }

  Future<bool> probeStt(
    SpeechToText platformStt, {
    bool recheckNegative = false,
  }) async {
    final locales = await platformStt.locales();
    final ids = _localeIds(locales);
    final available = ids.isNotEmpty;
    final english = ids.any((id) => _matchesLanguage(id, 'en'));
    final urdu = ids.any((id) => _matchesLanguage(id, 'ur'));

    await _writeCached('stt_available', available);
    await _writeCached('stt_english', english);
    await _writeCached('stt_urdu', urdu);

    // A missing locale can become available after the user installs a voice /
    // language pack. Rechecking negatives on resume is intentional.
    if (!recheckNegative) return available;
    _memoryCache['stt_available'] = available;
    _memoryCache['stt_english'] = english;
    _memoryCache['stt_urdu'] = urdu;
    return available;
  }

  Future<bool> sttAvailable({bool recheckNegative = false}) async {
    return _readOrProbe('stt_available', () async => false,
        recheckNegative: recheckNegative);
  }

  Future<bool> sttSupportsEnglish() async =>
      _readOrProbe('stt_english', () async => false);

  Future<bool> sttSupportsUrdu() async =>
      _readOrProbe('stt_urdu', () async => false);

  Future<void> _writeCached(String capability, bool value) async {
    _memoryCache[capability] = value;
    final prefs = await _prefsInstance;
    await prefs.setBool(_key(capability), value);
  }

  List<String> ttsCandidates(String deliveryLanguage) {
    switch (deliveryLanguage.toLowerCase()) {
      case 'urdu':
        return const ['ur-PK', 'ur-IN'];
      default:
        return const ['en-US', 'en-GB', 'en-IN'];
    }
  }

  Future<bool> ttsReliable(
    FlutterTts native,
    String deliveryLanguage, {
    bool recheckNegative = false,
  }) async {
    final language = deliveryLanguage.toLowerCase();
    return _readOrProbe(
      'tts_$language',
      () => _probeTts(native, language),
      recheckNegative: recheckNegative,
    );
  }

  Future<bool> recheckTtsIfMissing(
    FlutterTts native,
    String deliveryLanguage,
  ) => ttsReliable(native, deliveryLanguage, recheckNegative: true);

  Future<void> recheckIfMissing({SpeechToText? platformStt, FlutterTts? nativeTts}) async {
    if (platformStt != null) {
      final sttMissing = !(_memoryCache['stt_available'] ?? true);
      if (sttMissing) await probeStt(platformStt, recheckNegative: true);
    }
    if (nativeTts != null) {
      final englishMissing = !(_memoryCache['tts_english'] ?? true);
      final urduMissing = !(_memoryCache['tts_urdu'] ?? true);
      if (englishMissing) {
        await recheckTtsIfMissing(nativeTts, 'english');
      }
      if (urduMissing) {
        await recheckTtsIfMissing(nativeTts, 'urdu');
      }
    }
  }

  Future<bool> _probeTts(FlutterTts native, String deliveryLanguage) async {
    for (final locale in ttsCandidates(deliveryLanguage)) {
      try {
        await native.setLanguage(locale);
      } catch (e) {
        debugPrint('TTS capability setLanguage failed for $locale: $e');
        continue;
      }

      final completer = Completer<bool>();
      native.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete(true);
      });
      native.setErrorHandler((msg) {
        debugPrint('TTS capability probe error for $locale: $msg');
        if (!completer.isCompleted) completer.complete(false);
      });

      try {
        final result = await native.speak('.');
        if (result != 1) continue;
        final completed = await completer.future.timeout(
          _ttsProbeTimeout,
          onTimeout: () => false,
        );
        if (completed) return true;
      } catch (_) {}
    }
    return false;
  }

  Map<String, dynamic> debugSnapshot() => <String, dynamic>{
        'scope': _scope,
        'cached': jsonDecode(jsonEncode(_memoryCache)),
      };
}
