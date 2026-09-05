import 'dart:async';
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
/// Persisted results are scoped by platform + OS version. TTS results are also
/// scoped by the active engine so changing the Android TTS engine cannot reuse
/// a capability result produced by a different engine. Negative results are
/// rechecked after app resume so newly installed language packs are discovered
/// without paying the full probe cost on every app launch.
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

  bool _matchesLanguage(String locale, String language) =>
      _normalizeLocale(locale) == _normalizeLocale(language);

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

  Future<bool?> _cached(String capability) async {
    final memory = _memoryCache[capability];
    if (memory != null) return memory;
    final prefs = await _prefsInstance;
    final cached = prefs.getBool(_key(capability));
    if (cached != null) _memoryCache[capability] = cached;
    return cached;
  }

  Future<bool> _readOrProbe(
    String capability,
    Future<bool> Function() probe, {
    bool recheckNegative = false,
  }) async {
    final memory = _memoryCache[capability];
    if (memory == true || (memory == false && !recheckNegative)) return memory!;

    final prefs = await _prefsInstance;
    final cached = prefs.getBool(_key(capability));
    if (cached == true || (cached == false && !recheckNegative)) {
      _memoryCache[capability] = cached!;
      return cached;
    }

    final result = await probe();
    _memoryCache[capability] = result;
    await prefs.setBool(_key(capability), result);
    return result;
  }

  bool? get sttSupportsEnglishCached => _memoryCache['stt_english'];
  bool? get sttSupportsUrduCached => _memoryCache['stt_urdu'];

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
    return available;
  }

  Future<bool> sttAvailable({bool recheckNegative = false}) async {
    return _readOrProbe(
      'stt_available',
      () async => false,
      recheckNegative: recheckNegative,
    );
  }

  Future<bool> sttSupportsEnglish() async => _readOrProbe(
        'stt_english',
        () async => false,
      );

  Future<bool> sttSupportsUrdu() async => _readOrProbe(
        'stt_urdu',
        () async => false,
      );

  Future<bool> sttSupportsLanguage(String language) async {
    switch (_normalizeLocale(language)) {
      case 'ur':
        return sttSupportsUrdu();
      default:
        return sttSupportsEnglish();
    }
  }

  Future<String?> sttLocaleFor(SpeechToText platformStt, String language) async {
    final locales = _localeIds(await platformStt.locales());
    final wanted = _normalizeLocale(
      language == 'urdu' || language == 'roman urdu' ? 'ur' : 'en',
    );
    for (final locale in locales) {
      if (_normalizeLocale(locale) == wanted) return locale;
    }
    return null;
  }

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

  Future<String> _ttsEngineId(FlutterTts native) async {
    if (!Platform.isAndroid) return 'default';
    try {
      final engine = await native.getDefaultEngine;
      if (engine != null && engine.toString().trim().isNotEmpty) {
        return engine.toString().trim();
      }
    } catch (e) {
      debugPrint('TTS engine lookup failed; using default cache scope: $e');
    }
    return 'default';
  }

  Future<bool> ttsReliable(
    FlutterTts native,
    String deliveryLanguage, {
    bool recheckNegative = false,
  }) async {
    final language = deliveryLanguage.toLowerCase();
    final engineId = await _ttsEngineId(native);
    final capability = 'tts_engine_${engineId}_$language';
    return _readOrProbe(
      capability,
      () => _probeTts(native, language),
      recheckNegative: recheckNegative,
    );
  }

  Future<bool> recheckTtsIfMissing(
    FlutterTts native,
    String deliveryLanguage,
  ) => ttsReliable(native, deliveryLanguage, recheckNegative: true);

  Future<void> recheckIfMissing({
    SpeechToText? platformStt,
    FlutterTts? nativeTts,
  }) async {
    if (platformStt != null) {
      // Recheck when *any* tracked sub-capability is not yet positively known.
      // An absent cache entry is distinct from a verified negative and must
      // be probed before callers treat the capability as unavailable.
      final available = await _cached('stt_available');
      final english = await _cached('stt_english');
      final urdu = await _cached('stt_urdu');
      final hasMissing =
          available != true || english != true || urdu != true;
      if (hasMissing) {
        await probeStt(platformStt, recheckNegative: true);
      }
    }
    if (nativeTts != null) {
      final engineId = await _ttsEngineId(nativeTts);
      for (final language in const ['english', 'urdu']) {
        final capability = 'tts_engine_${engineId}_$language';
        final cached = await _cached(capability);
        if (cached != true) {
          await recheckTtsIfMissing(nativeTts, language);
        }
      }
    }
  }

  Future<bool> _probeTts(FlutterTts native, String deliveryLanguage) async {
    // The probe is a real synthesis call, so it must be silent: it runs on
    // app resume and on Everyday warm-up, without the user asking for any
    // speech. Left audible, a device with no Urdu voice re-probes on every
    // resume and the app appears to talk to itself. Volume is restored to
    // the app default that initialize() sets before any user-facing speech.
    try {
      await native.setVolume(0.0);
    } catch (e) {
      debugPrint('TTS capability probe could not mute output: $e');
    }
    try {
      return await _probeTtsAtCurrentVolume(native, deliveryLanguage);
    } finally {
      try {
        await native.setVolume(1.0);
      } catch (e) {
        debugPrint('TTS capability probe could not restore volume: $e');
      }
    }
  }

  Future<bool> _probeTtsAtCurrentVolume(
    FlutterTts native,
    String deliveryLanguage,
  ) async {
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
}
