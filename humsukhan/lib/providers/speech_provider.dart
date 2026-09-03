import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/models.dart';
import '../services/cloud_tts_service.dart';
import '../services/everyday_language_policy.dart';
import '../services/roman_urdu_detector.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';
import '../services/tts_engine.dart';

abstract class TtsProvider implements TtsEngine {}

class ResilientTtsProvider implements TtsProvider {
  final FlutterTts _native = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cloudCache = <String, Uint8List>{};
  bool _speaking = false;
  bool _initialized = false;
  int _speakGeneration = 0;
  static const int _maxCloudCacheEntries = 12;
  static const Duration _nativeSpeechTimeout = Duration(seconds: 90);

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _native.awaitSpeakCompletion(true);
      await _native.setSpeechRate(0.5);
      await _native.setVolume(1.0);
      await _native.setPitch(1.0);
      try { await _native.getVoices; } catch (_) {}
      _native.setStartHandler(() => _speaking = true);
      _native.setCompletionHandler(() => _speaking = false);
      _native.setCancelHandler(() => _speaking = false);
      _native.setErrorHandler((_) => _speaking = false);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      return false;
    }
  }

  Future<bool> warmUp() => initialize();

  String _deliveryLanguage(String language, String text) {
    final sanitized = EverydayLanguagePolicy.sanitizeHindi(text);
    if (sanitized.isEmpty) return 'english';
    if (EverydayLanguagePolicy.containsUrduScript(sanitized)) return 'urdu';
    if (RomanUrduDetector.isRomanUrdu(sanitized)) return 'urdu';
    return 'english';
  }

  List<String> _nativeLocaleCandidates(String deliveryLanguage) {
    switch (deliveryLanguage) {
      case 'urdu':
        return const ['ur-PK', 'ur-IN'];
      default:
        return const ['en-US', 'en-GB', 'en-IN'];
    }
  }

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

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    final sanitized = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (sanitized.isEmpty) return;
    final generation = ++_speakGeneration;
    _speaking = true;
    try {
      await initialize();
      final deliveryLanguage = _deliveryLanguage(language, sanitized);
      final nativeReady = await _setNativeLocale(deliveryLanguage);
      if (nativeReady) {
        try {
          await _native.speak(sanitized).timeout(_nativeSpeechTimeout);
          if (generation == _speakGeneration) return;
        } catch (e) {
          debugPrint('Native TTS failed, using cloud fallback: $e');
        }
      }

      if (generation != _speakGeneration) return;
      final cacheKey = '$deliveryLanguage:${sanitized.toLowerCase()}';
      final cached = _cloudCache[cacheKey];
      if (cached != null) {
        await _player.play(BytesSource(cached));
        return;
      }
      final audio = await CloudTtsService.instance.synthesize(
        sanitized,
        language: deliveryLanguage,
      );
      if (audio == null || generation != _speakGeneration) return;
      if (_cloudCache.length >= _maxCloudCacheEntries) {
        _cloudCache.remove(_cloudCache.keys.first);
      }
      _cloudCache[cacheKey] = audio;
      await _player.play(BytesSource(audio));
    } finally {
      if (generation == _speakGeneration) _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    ++_speakGeneration;
    try { await _native.stop(); } catch (_) {}
    try { await _player.stop(); } catch (_) {}
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  void dispose() {
    ++_speakGeneration;
    _native.stop();
    _player.dispose();
    _cloudCache.clear();
  }
}
