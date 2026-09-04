// Shared native/cloud TTS delivery used by EverydaySpeechProvider (see
// providers/everyday_speech_provider.dart, which owns the app's actual
// SpeechProvider). This file previously also defined its own standalone
// SpeechProvider (STT+TTS) implementation; that class was never wired into
// the provider tree in main.dart -- the app only ever constructed the
// EverydaySpeechProvider-based SpeechProvider -- so it was dead code and was
// removed rather than left as a second, divergent "shared" implementation.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/cloud_tts_service.dart';
import '../services/everyday_language_policy.dart';
import '../services/roman_urdu_detector.dart';
import '../services/speech_capability.dart';
import '../services/tts_engine.dart';

abstract class TtsProvider implements TtsEngine {}

class ResilientTtsProvider implements TtsProvider {
  final FlutterTts _native = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cloudCache = <String, Uint8List>{};
  final SpeechCapability _capability = SpeechCapability.instance;
  bool _speaking = false;
  bool _initialized = false;
  int _speakGeneration = 0;
  Future<void> _nativeLock = Future.value();
  static const int _maxCloudCacheEntries = 12;
  static const Duration _nativeSpeechTimeout = Duration(seconds: 90);

  Future<T> _withNativeLock<T>(Future<T> Function() action) {
    final previous = _nativeLock;
    final completer = Completer<void>();
    _nativeLock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _native.awaitSpeakCompletion(true);
      await _native.setSpeechRate(0.5);
      await _native.setVolume(1.0);
      await _native.setPitch(1.0);
      try {
        await _native.getVoices;
      } catch (_) {}
      _installPlaybackHandlers();
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      return false;
    }
  }

  void _installPlaybackHandlers() {
    _native.setStartHandler(() => _speaking = true);
    _native.setCompletionHandler(() => _speaking = false);
    _native.setCancelHandler(() => _speaking = false);
    _native.setErrorHandler((_) => _speaking = false);
  }

  Future<bool> warmUp() async {
    final ok = await initialize();
    if (ok) {
      unawaited(_withNativeLock(() async {
        await _capability.ttsReliable(_native, 'english');
        await _capability.ttsReliable(_native, 'urdu');
        _installPlaybackHandlers();
      }));
    }
    return ok;
  }

  Future<void> recheckMissingCapabilities() async {
    await _withNativeLock(() async {
      await _capability.recheckIfMissing(nativeTts: _native);
      _installPlaybackHandlers();
    });
  }

  String _deliveryLanguage(String language, String text) {
    final sanitized = EverydayLanguagePolicy.sanitizeHindi(text);
    if (sanitized.isEmpty) return 'english';
    if (EverydayLanguagePolicy.containsUrduScript(sanitized)) return 'urdu';
    if (RomanUrduDetector.isRomanUrdu(sanitized)) return 'urdu';
    return 'english';
  }

  List<String> _nativeLocaleCandidates(String deliveryLanguage) =>
      _capability.ttsCandidates(deliveryLanguage);

  Future<bool> _setNativeLocale(String deliveryLanguage) async {
    for (final locale in _nativeLocaleCandidates(deliveryLanguage)) {
      try {
        final available = await _native.isLanguageAvailable(locale);
        if (available == true || available.toString().toLowerCase() == 'true') {
          await _native.setLanguage(locale);
          return true;
        }
      } catch (_) {}
    }

    try {
      final voices = await _native.getVoices;
      if (voices is List) {
        final prefix = deliveryLanguage == 'urdu' ? 'ur' : 'en';
        for (final raw in voices) {
          if (raw is! Map) continue;
          final locale = raw['locale']?.toString() ?? '';
          if (locale.toLowerCase().startsWith(prefix)) {
            await _native.setVoice(<String, String>{
              'name': raw['name']?.toString() ?? '',
              'locale': locale,
            });
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _speakNative(String text, String deliveryLanguage) =>
      _withNativeLock(() => _speakNativeLocked(text, deliveryLanguage));

  Future<void> _speakNativeLocked(String text, String deliveryLanguage) async {
    final reliable = await _capability.ttsReliable(_native, deliveryLanguage);
    _installPlaybackHandlers();
    if (!reliable) {
      throw StateError(
        'No verified ${deliveryLanguage[0].toUpperCase()}${deliveryLanguage.substring(1)} device voice on this phone',
      );
    }

    final ready = await _setNativeLocale(deliveryLanguage);
    if (!ready) {
      throw StateError(
        'No installed ${deliveryLanguage[0].toUpperCase()}${deliveryLanguage.substring(1)} device voice is available',
      );
    }

    _speaking = true;
    try {
      await _native.speak(text);
      final deadline = DateTime.now().add(_nativeSpeechTimeout);
      while (_speaking && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (_speaking) {
        try {
          await _native.stop();
        } catch (_) {}
        _speaking = false;
        throw TimeoutException(
          'Native TTS did not complete within ${_nativeSpeechTimeout.inSeconds} seconds',
        );
      }
    } finally {
      _speaking = false;
    }
  }

  Future<void> _speakCloud(String text, String deliveryLanguage) async {
    final key = '$deliveryLanguage|${text.trim()}';
    Uint8List? bytes = _cloudCache[key];
    if (bytes == null) {
      final result = await CloudTtsService.instance.synthesize(
        text: text,
        language: deliveryLanguage,
      );
      bytes = Uint8List.fromList(result.audioBytes);
      if (_cloudCache.length >= _maxCloudCacheEntries) {
        _cloudCache.remove(_cloudCache.keys.first);
      }
      _cloudCache[key] = bytes;
    }

    await _player.stop();
    _speaking = true;
    final completion = _player.onPlayerStateChanged.firstWhere(
      (state) => state == PlayerState.completed || state == PlayerState.stopped,
    );
    try {
      await _player.play(BytesSource(bytes));
      await completion.timeout(const Duration(seconds: 30));
    } finally {
      _speaking = false;
    }
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    final value = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (value.isEmpty) return;
    await initialize();

    final generation = ++_speakGeneration;
    final deliveryLanguage = _deliveryLanguage(language, value);
    await _stopPlaybackOnly();

    try {
      await _speakNative(value, deliveryLanguage);
      if (generation != _speakGeneration) return;
      return;
    } catch (e) {
      if (generation != _speakGeneration) return;
      debugPrint('Native TTS unavailable; falling back to cloud TTS: $e');
    }

    if (generation != _speakGeneration) return;
    try {
      await _speakCloud(value, deliveryLanguage);
      if (generation != _speakGeneration) return;
    } catch (e) {
      if (generation != _speakGeneration) return;
      debugPrint('Cloud TTS unavailable: $e');
      rethrow;
    }
  }

  Future<void> _stopPlaybackOnly() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _withNativeLock(() => _native.stop());
    } catch (_) {}
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    ++_speakGeneration;
    await _stopPlaybackOnly();
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  void dispose() {
    ++_speakGeneration;
    _cloudCache.clear();
    unawaited(_player.dispose());
    unawaited(_withNativeLock(() => _native.stop()));
  }
}
