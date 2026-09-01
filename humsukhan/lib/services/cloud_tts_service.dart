import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class CloudTtsResult {
  final Uint8List audio;
  final String mimeType;
  final String provider;
  final String language;

  const CloudTtsResult({
    required this.audio,
    required this.mimeType,
    required this.provider,
    required this.language,
  });
}

/// Cloud-backed TTS used by Conversational Mode and other caption playback.
///
/// Routing is performed server-side so provider credentials never reach the
/// client. English is synthesized by Deepgram; Urdu and Roman Urdu use Soniox.
class CloudTtsService {
  CloudTtsService._();
  static final CloudTtsService instance = CloudTtsService._();

  final AudioPlayer _player = AudioPlayer();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<CloudTtsResult?> synthesize(
    String text, {
    String language = 'English',
  }) async {
    final value = text.trim();
    if (value.isEmpty) return null;

    final client = SupabaseService.instance.client;
    if (client == null) {
      debugPrint('Cloud TTS unavailable: Supabase client is not initialized');
      return null;
    }

    try {
      final response = await client.functions.invoke(
        'speech-synthesis',
        body: {
          'text': value,
          'language': language,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final encoded = data['audioBase64']?.toString() ?? '';
      if (encoded.isEmpty) return null;

      return CloudTtsResult(
        audio: base64Decode(encoded),
        mimeType: data['mimeType']?.toString() ?? 'audio/mpeg',
        provider: data['provider']?.toString() ?? 'unknown',
        language: data['language']?.toString() ?? language,
      );
    } catch (e) {
      debugPrint('Cloud TTS synthesis failed: $e');
      return null;
    }
  }

  Future<void> speak(
    String text, {
    String language = 'English',
  }) async {
    final result = await synthesize(text, language: language);
    if (result == null || result.audio.isEmpty) return;

    await stop();
    _speaking = true;
    try {
      final completed = _player.onPlayerComplete.first;
      await _player.play(BytesSource(result.audio, mimeType: result.mimeType));
      await completed;
    } catch (e) {
      debugPrint('Cloud TTS playback failed: $e');
    } finally {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Cloud TTS stop failed: $e');
    }
    _speaking = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
    _speaking = false;
  }
}
