import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'supabase_service.dart';

class DeepgramTranscriptResult {
  final String transcript;
  final String language;
  final double confidence;
  const DeepgramTranscriptResult({required this.transcript, required this.language, this.confidence = 0.0});
}

class DeepgramTranscriptionService {
  static DeepgramTranscriptionService? _instance;
  static DeepgramTranscriptionService get instance => _instance ??= DeepgramTranscriptionService._();
  DeepgramTranscriptionService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  String? _path;
  bool get isRecording => _recording;

  Future<bool> start() async {
    if (_recording) return true;
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/humsukhan-dg-${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: _path!);
      _recording = true;
      return true;
    } catch (e) {
      debugPrint('Deepgram recorder start failed: $e');
      _recording = false;
      return false;
    }
  }

  Future<DeepgramTranscriptResult?> stopAndTranscribe({String language = 'auto'}) async {
    if (!_recording) return null;
    _recording = false;
    final recordedPath = await _recorder.stop();
    final filePath = recordedPath ?? _path;
    _path = null;
    if (filePath == null) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length <= 44) {
      await file.delete().catchError((_) => file);
      return null;
    }
    try {
      final response = await SupabaseService.instance.client!.functions.invoke(
        'deepgram-transcribe-bilingual',
        body: {'audioBase64': base64Encode(bytes), 'mimeType': 'audio/wav', 'language': language, 'sampleRate': 16000, 'channels': 1},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return DeepgramTranscriptResult(
        transcript: data['transcript']?.toString().trim() ?? '',
        language: data['detectedLanguage']?.toString() ?? data['language']?.toString() ?? 'en',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Deepgram transcription failed: $e');
      return null;
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  Future<void> cancel() async {
    _recording = false;
    _path = null;
    try { await _recorder.cancel(); } catch (_) {}
  }

  void dispose() => _recorder.dispose();
}
