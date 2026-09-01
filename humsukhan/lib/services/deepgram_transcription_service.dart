import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
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

/// Low-latency Deepgram streaming STT used by Conversational Auto mode.
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
  String? _lastStartError;

  Stream<DeepgramTranscriptResult> get onResult => _controller.stream;
  bool get isRecording => _recording;
  String? get lastStartError => _lastStartError;

  Future<bool> start({String language = 'auto'}) async {
    if (_recording) return true;
    _lastStartError = null;

    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      _lastStartError = 'Speech service is not signed in. Please sign in again.';
      debugPrint(_lastStartError!);
      return false;
    }

    try {
      final permission = await Permission.microphone.status;
      if (!permission.isGranted) {
        final requested = await Permission.microphone.request();
        if (!requested.isGranted) {
          _lastStartError = requested.isPermanentlyDenied
              ? 'Microphone access is blocked in Android settings.'
              : 'Microphone access was not granted.';
          debugPrint(_lastStartError!);
          return false;
        }
      }

      // record has its own Android-side permission check. Do this after the
      // runtime permission request so a stale plugin state cannot immediately
      // turn into the generic "microphone did not start" message.
      if (!await _recorder.hasPermission()) {
        _lastStartError = 'Android granted microphone access, but the audio recorder could not acquire it.';
        debugPrint(_lastStartError!);
        return false;
      }

      final tokenResponse = await client.functions
          .invoke('deepgram-token')
          .timeout(const Duration(seconds: 5));
      final raw = tokenResponse.data;
      if (raw is! Map) throw StateError('Deepgram token service returned an invalid response');
      final tokenData = Map<String, dynamic>.from(raw);
      final token = tokenData['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        throw StateError(tokenData['error']?.toString() ?? 'Deepgram token service returned no token');
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
      ).timeout(const Duration(seconds: 7));

      _lastInterim = '';
      _finalBuffer = '';
      _socketSubscription = _socket!.listen(
        _handleSocketMessage,
        onError: (Object error) {
          debugPrint('Deepgram WebSocket error: $error');
        },
        onDone: () {
          if (_recording) {
            _lastStartError = 'The live speech connection closed unexpectedly.';
          }
        },
        cancelOnError: false,
      );

      // Mark active immediately before attaching the recorder listener. This
      // prevents the first PCM frame from being dropped during startup.
      _recording = true;
      try {
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
          cancelOnError: false,
        );
      } catch (e) {
        _recording = false;
        _lastStartError = 'The Android microphone recorder could not start: $e';
        rethrow;
      }

      return true;
    } catch (e) {
      _lastStartError ??= 'Could not start live speech recognition: $e';
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
      if (data is! Map || data['type'] != 'Results') return;
      final channel = data['channel'];
      final alternatives = channel is Map ? channel['alternatives'] : null;
      final alternative = alternatives is List && alternatives.isNotEmpty ? alternatives.first : null;
      if (alternative is! Map) return;

      final text = alternative['transcript']?.toString().trim() ?? '';
      if (text.isEmpty) return;
      final confidence = (alternative['confidence'] as num?)?.toDouble() ?? 0.0;
      final isFinal = data['is_final'] == true;
      final speechFinal = data['speech_final'] == true;
      final language = alternative['detected_language']?.toString() ?? _language;

      if (isFinal) {
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
