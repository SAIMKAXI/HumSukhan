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

/// Persistent low-latency Deepgram streaming STT.
///
/// The WebSocket is kept alive between microphone turns so every turn does not
/// pay token + TLS/WebSocket setup latency. Stopping the microphone first stops
/// new audio, then explicitly finalizes the current stream and waits for the
/// server's final packet before the socket is cleaned up.
class DeepgramTranscriptionService {
  static DeepgramTranscriptionService? _instance;
  static DeepgramTranscriptionService get instance => _instance ??= DeepgramTranscriptionService._();
  DeepgramTranscriptionService._();

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<DeepgramTranscriptResult> _controller = StreamController.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Completer<void>? _finalizationCompleter;

  bool _recording = false;
  bool _sessionReady = false;
  String _language = 'multi';
  String _finalBuffer = '';
  String _lastFinalTranscript = '';
  String? _lastStartError;
  DateTime? _turnStartedAt;
  DateTime? _firstTranscriptAt;

  Stream<DeepgramTranscriptResult> get onResult => _controller.stream;
  bool get isRecording => _recording;
  bool get isSessionReady => _sessionReady && _socket?.readyState == WebSocket.open;
  String? get lastStartError => _lastStartError;
  String get lastFinalTranscript => _lastFinalTranscript;

  Future<bool> _ensureSession(String language) async {
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      _lastStartError = 'Authenticated Supabase session is unavailable.';
      return false;
    }

    final normalized = _normalizeLanguage(language);
    if (isSessionReady && normalized == _language) return true;

    await _closeSocketOnly();
    _language = normalized;

    final tokenResponse = await client.functions.invoke('deepgram-token').timeout(const Duration(seconds: 5));
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

    final endpointingMs = _language == 'multi' ? '300' : '350';
    final query = <String, String>{
      'model': 'nova-3',
      'language': _language,
      'encoding': 'linear16',
      'sample_rate': '16000',
      'channels': '1',
      'interim_results': 'true',
      'smart_format': 'true',
      'punctuate': 'true',
      'endpointing': endpointingMs,
      'utterance_end_ms': '1000',
      'vad_events': 'true',
    };

    final uri = Uri.parse('wss://api.deepgram.com/v1/listen').replace(queryParameters: query);
    _socket = await WebSocket.connect(
      uri.toString(),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 6));

    _sessionReady = true;
    _finalBuffer = '';
    _socketSubscription = _socket!.listen(
      _handleSocketMessage,
      onError: (Object error) {
        _sessionReady = false;
        _lastStartError = 'Deepgram streaming connection failed.';
        debugPrint('Deepgram WebSocket error: $error');
      },
      onDone: () {
        _sessionReady = false;
        if (_recording) {
          _lastStartError = 'Deepgram streaming connection closed unexpectedly.';
          debugPrint(_lastStartError);
        }
      },
      cancelOnError: false,
    );
    return true;
  }

  Future<bool> start({String language = 'auto'}) async {
    if (_recording) return true;
    _lastStartError = null;
    _lastFinalTranscript = '';
    _turnStartedAt = DateTime.now();
    _firstTranscriptAt = null;

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

      if (!await _ensureSession(language)) return false;

      _finalBuffer = '';
      _lastFinalTranscript = '';
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _recording = true;
      debugPrint('Speech latency: microphone stream started at $_turnStartedAt');
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
      case 'hindi':
      case 'hi':
        // Hindi is not a separate product route. Treat an accidental Hindi
        // preference as English so Auto/EN/UR remain the only supported modes.
        return 'en-US';
      case 'auto':
      case 'multi':
      case 'mixed':
        return 'multi';
      default:
        return 'en-US';
    }
  }

  void _handleSocketMessage(dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message);
      if (data is! Map || data['type'] != 'Results') return;
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
      final rawLanguage = alternative['detected_language']?.toString();
      final language = rawLanguage == null || rawLanguage.isEmpty ? _language : rawLanguage;

      _firstTranscriptAt ??= DateTime.now();
      if (_turnStartedAt != null) {
        debugPrint('Speech latency: first transcript ${DateTime.now().difference(_turnStartedAt!).inMilliseconds}ms after microphone start');
      }

      if (isFinal) {
        _finalBuffer = _finalBuffer.isEmpty ? text : '$_finalBuffer $text';
      }

      if (speechFinal) {
        final complete = _finalBuffer.trim().isNotEmpty ? _finalBuffer.trim() : text;
        _lastFinalTranscript = complete;
        _controller.add(DeepgramTranscriptResult(
          transcript: complete,
          language: _displayLanguage(language, complete),
          confidence: confidence,
          isFinal: true,
          speechFinal: true,
        ));
        if (_turnStartedAt != null) {
          debugPrint('Speech latency: speech_final ${DateTime.now().difference(_turnStartedAt!).inMilliseconds}ms after microphone start');
        }
        _finalBuffer = '';
        _finalizationCompleter?.complete();
        _finalizationCompleter = null;
        return;
      }

      _controller.add(DeepgramTranscriptResult(
        transcript: text,
        language: _displayLanguage(language, text),
        confidence: confidence,
        isFinal: isFinal,
        speechFinal: false,
      ));
    } catch (e) {
      debugPrint('Deepgram result parse failed: $e');
    }
  }

  String _displayLanguage(String value, String text) {
    final v = value.toLowerCase();
    if (v.startsWith('ur')) return 'Urdu';
    // Deliberately do not expose Hindi as a product language. Auto-detected
    // Devanagari is treated as the English fallback route.
    if (v.startsWith('hi')) return 'English';
    if (v.startsWith('en')) return 'English';
    if (v == 'multi') {
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'Urdu';
      return 'Auto';
    }
    return 'English';
  }

  Future<void> stop() async {
    if (!_recording && !isSessionReady) return;

    _recording = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}

    if (_socket?.readyState == WebSocket.open) {
      _finalizationCompleter = Completer<void>();
      try {
        _socket!.add(jsonEncode({'type': 'Finalize'}));
        await _finalizationCompleter!.future.timeout(const Duration(milliseconds: 1400));
      } catch (_) {
        if (_finalBuffer.trim().isNotEmpty && _lastFinalTranscript.trim().isEmpty) {
          _lastFinalTranscript = _finalBuffer.trim();
        }
      } finally {
        _finalizationCompleter = null;
        if (_turnStartedAt != null && _lastFinalTranscript.trim().isNotEmpty) {
          debugPrint('Speech latency: final transcript ready in ${DateTime.now().difference(_turnStartedAt!).inMilliseconds}ms');
        }
      }
    }
  }

  Future<void> _closeSocketOnly() async {
    _sessionReady = false;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _socket?.close(WebSocketStatus.normalClosure, 'session reset');
    } catch (_) {}
    _socket = null;
  }

  Future<void> _cleanup() async {
    _recording = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _closeSocketOnly();
    _finalBuffer = '';
    _finalizationCompleter = null;
  }

  Future<void> cancel() async => _cleanup();
  Future<void> closeSession() async => _cleanup();

  void dispose() {
    unawaited(_cleanup());
    _controller.close();
    _recorder.dispose();
  }
}
