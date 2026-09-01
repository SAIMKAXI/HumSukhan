import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'supabase_service.dart';

class DeepgramTranscriptResult {
  final String transcript;
  final String language;
  final double confidence;
  final bool isFinal;
  final bool speechFinal;

  const DeepgramTranscriptResult({
    required this.transcript,
    required this.language,
    this.confidence = 0.0,
    this.isFinal = false,
    this.speechFinal = false,
  });
}

/// Low-latency Deepgram streaming STT.
///
/// Audio is streamed as 16 kHz PCM directly from the microphone to Deepgram.
/// The permanent Deepgram key never reaches the device: Supabase issues a
/// short-lived Deepgram token through the authenticated deepgram-token Edge
/// Function. Interim results are emitted continuously for live captions.
class DeepgramTranscriptionService {
  static DeepgramTranscriptionService? _instance;
  static DeepgramTranscriptionService get instance => _instance ??= DeepgramTranscriptionService._();
  DeepgramTranscriptionService._();

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<DeepgramTranscriptResult> _controller = StreamController.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _recording = false;
  String _language = 'multi';
  String _lastInterim = '';
  String _finalBuffer = '';

  Stream<DeepgramTranscriptResult> get onResult => _controller.stream;
  bool get isRecording => _recording;

  Future<bool> start({String language = 'auto'}) async {
    if (_recording) return true;
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      debugPrint('Deepgram streaming unavailable: authenticated Supabase session required');
      return false;
    }
    if (!await _recorder.hasPermission()) return false;

    try {
      final tokenResponse = await client.functions
          .invoke('deepgram-token')
          .timeout(const Duration(seconds: 5));
      final tokenData = Map<String, dynamic>.from(tokenResponse.data as Map);
      final token = tokenData['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        debugPrint('Deepgram token endpoint returned no access token');
        return false;
      }

      _language = _normalizeLanguage(language);
      final query = <String, String>{
        'model': 'nova-3',
        'language': _language,
        'encoding': 'linear16',
        'sample_rate': '16000',
        'channels': '1',
        'interim_results': 'true',
        'smart_format': 'true',
        'punctuate': 'true',
        'endpointing': _language == 'multi' ? '100' : '300',
        'utterance_end_ms': '1000',
        'vad_events': 'true',
      };
      final uri = Uri.parse('wss://api.deepgram.com/v1/listen').replace(queryParameters: query);
      _socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      _lastInterim = '';
      _finalBuffer = '';
      _socketSubscription = _socket!.listen(
        _handleSocketMessage,
        onError: (Object error) => debugPrint('Deepgram WebSocket error: $error'),
        onDone: () {
          if (_recording) debugPrint('Deepgram WebSocket closed unexpectedly');
        },
        cancelOnError: false,
      );

      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _audioSubscription = stream.listen(
        (data) {
          if (_recording && _socket?.readyState == WebSocket.open) {
            _socket!.add(data);
          }
        },
        onError: (Object error) => debugPrint('Deepgram microphone stream error: $error'),
      );
      _recording = true;
      return true;
    } catch (e) {
      debugPrint('Deepgram streaming start failed: $e');
      await _cleanup();
      return false;
    }
  }

  String _normalizeLanguage(String language) {
    switch (language.toLowerCase().trim()) {
      case 'urdu':
      case 'ur':
      case 'roman urdu':
        return 'ur';
      case 'english':
      case 'en':
      case 'en-us':
        return 'en-US';
      case 'auto':
      case 'multi':
      case 'mixed':
        return 'multi';
      default:
        return language;
    }
  }

  void _handleSocketMessage(dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;
      if (data['type'] == 'Results') {
        final alternative = data['channel']?['alternatives']?[0];
        if (alternative is! Map) return;
        final text = alternative['transcript']?.toString().trim() ?? '';
        if (text.isEmpty) return;
        final confidence = (alternative['confidence'] as num?)?.toDouble() ?? 0.0;
        final isFinal = data['is_final'] == true;
        final speechFinal = data['speech_final'] == true;
        final language = data['channel']?['alternatives']?[0]?['detected_language']?.toString() ?? _language;

        if (isFinal) {
          // Deepgram sends rolling final segments. Keep a complete utterance
          // buffer while exposing the current segment immediately to the UI.
          _finalBuffer = _finalBuffer.isEmpty ? text : '$_finalBuffer $text';
          _lastInterim = '';
        } else {
          _lastInterim = text;
        }

        _controller.add(DeepgramTranscriptResult(
          transcript: text,
          language: _displayLanguage(language),
          confidence: confidence,
          isFinal: isFinal,
          speechFinal: speechFinal,
        ));

        if (speechFinal) {
          final complete = _finalBuffer.trim().isNotEmpty ? _finalBuffer.trim() : text;
          if (complete.isNotEmpty && complete != text) {
            _controller.add(DeepgramTranscriptResult(
              transcript: complete,
              language: _displayLanguage(language),
              confidence: confidence,
              isFinal: true,
              speechFinal: true,
            ));
          }
          _finalBuffer = '';
          _lastInterim = '';
        }
      }
    } catch (e) {
      debugPrint('Deepgram result parse failed: $e');
    }
  }

  String _displayLanguage(String value) {
    final v = value.toLowerCase();
    if (v.startsWith('ur')) return 'Urdu';
    if (v.startsWith('en')) return 'English';
    if (v == 'multi') return 'Auto';
    return value;
  }

  Future<void> stop() async {
    if (!_recording && _socket == null) return;
    _recording = false;
    try {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode({'type': 'Finalize'}));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (_) {}
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _recording = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try { await _recorder.stop(); } catch (_) {}
    try { await _socket?.close(WebSocketStatus.normalClosure, 'client stopped'); } catch (_) {}
    _socket = null;
    _lastInterim = '';
    _finalBuffer = '';
  }

  Future<void> cancel() async => _cleanup();

  void dispose() {
    unawaited(_cleanup());
    _controller.close();
    _recorder.dispose();
  }
}
