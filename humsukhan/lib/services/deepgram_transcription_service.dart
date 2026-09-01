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
  String _finalBuffer = '';
  String _lastFinalTranscript = '';
  String? _lastStartError;

  Stream<DeepgramTranscriptResult> get onResult => _controller.stream;
  bool get isRecording => _recording;
  String? get lastStartError => _lastStartError;
  String get lastFinalTranscript => _lastFinalTranscript;

  Future<bool> start({String language = 'auto'}) async {
    if (_recording) return true;
    _lastStartError = null;
    _lastFinalTranscript = '';

    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      _lastStartError = 'Authenticated Supabase session is unavailable.';
      debugPrint('Deepgram streaming unavailable: $_lastStartError');
      return false;
    }

    try {
      final permissionStatus = await Permission.microphone.status;
      if (!permissionStatus.isGranted) {
        final requested = await Permission.microphone.request();
        if (!requested.isGranted) {
          _lastStartError = requested.isPermanentlyDenied
              ? 'Microphone permission is blocked in Android settings.'
              : 'Microphone permission was not granted.';
          return false;
        }
      }
      if (!await _recorder.hasPermission()) {
        _lastStartError = 'Android granted microphone permission, but the recorder cannot access the microphone.';
        return false;
      }

      final tokenResponse = await client.functions
          .invoke('deepgram-token')
          .timeout(const Duration(seconds: 5));
      final rawData = tokenResponse.data;
      if (rawData is! Map) {
        _lastStartError = 'Deepgram token service returned an invalid response.';
        return false;
      }
      final tokenData = Map<String, dynamic>.from(rawData);
      final token = tokenData['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        _lastStartError = 'Deepgram token service returned no access token.';
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

      _finalBuffer = '';
      _socketSubscription = _socket!.listen(
        _handleSocketMessage,
        onError: (Object error) {
          _lastStartError = 'Deepgram streaming connection failed.';
          debugPrint('Deepgram WebSocket error: $error');
        },
        onDone: () {
          if (_recording) {
            _lastStartError = 'Deepgram streaming connection closed unexpectedly.';
            debugPrint(_lastStartError);
          }
        },
        cancelOnError: false,
      );

      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _recording = true;
      _audioSubscription = stream.listen(
        (data) {
          if (_recording && _socket?.readyState == WebSocket.open) {
            _socket!.add(data);
          }
        },
        onError: (Object error) {
          _lastStartError = 'Android microphone stream failed.';
          debugPrint('Deepgram microphone stream error: $error');
        },
      );
      return true;
    } catch (e) {
      _lastStartError = 'Speech microphone startup failed: $e';
      debugPrint(_lastStartError);
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
        final channel = data['channel'];
        if (channel is! Map) return;
        final alternatives = channel['alternatives'];
        if (alternatives is! List || alternatives.isEmpty || alternatives.first is! Map) return;
        final alternative = Map<String, dynamic>.from(alternatives.first as Map);
        final text = alternative['transcript']?.toString().trim() ?? '';
        if (text.isEmpty) return;
        final confidence = (alternative['confidence'] as num?)?.toDouble() ?? 0.0;
        final isFinal = data['is_final'] == true;
        final speechFinal = data['speech_final'] == true;
        final language = alternative['detected_language']?.toString() ?? _language;

        if (isFinal) {
          _finalBuffer = _finalBuffer.isEmpty ? text : '$_finalBuffer $text';
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
          _lastFinalTranscript = complete;
          _controller.add(DeepgramTranscriptResult(
            transcript: complete,
            language: _displayLanguage(language),
            confidence: confidence,
            isFinal: true,
            speechFinal: true,
          ));
          _finalBuffer = '';
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
        await Future<void>.delayed(const Duration(milliseconds: 400));
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
    _finalBuffer = '';
  }

  Future<void> cancel() async => _cleanup();

  void dispose() {
    unawaited(_cleanup());
    _controller.close();
    _recorder.dispose();
  }
}
