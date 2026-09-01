import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class OfflineSTTProvider {
  Future<bool> initialize({String modelPath = ''});
  Future<void> startListening({String language = 'English'});
  Future<void> stopListening();
  Stream<OfflineSTTResult> get onResult;
  bool get isListening;
  bool get isAvailable;
  String get currentModel;
  void dispose();
}

class OfflineSTTResult {
  final String text;
  final bool isFinal;
  final double confidence;

  const OfflineSTTResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
  });
}

class MockOfflineSTT implements OfflineSTTProvider {
  final _controller = StreamController<OfflineSTTResult>.broadcast();
  bool _listening = false;
  bool _available = false;
  String _model = 'mock-english-v1';

  @override
  String get currentModel => _model;

  @override
  Future<bool> initialize({String modelPath = ''}) async {
    _available = true;
    _model = modelPath.isNotEmpty ? modelPath : 'mock-english-v1';
    debugPrint('Offline STT initialized with model: $_model');
    return true;
  }

  @override
  Future<void> startListening({String language = 'English'}) async {
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  @override
  Stream<OfflineSTTResult> get onResult => _controller.stream;

  @override
  bool get isListening => _listening;

  @override
  bool get isAvailable => _available;

  @override
  void dispose() {
    _controller.close();
  }
}

/*
 * PRODUCTION IMPLEMENTATION OPTIONS:
 *
 * Option 1: Vosk (Recommended for mobile)
 * - Lightweight (~50MB model), good accuracy, multiple languages
 *
 * Option 2: Whisper.cpp (Best accuracy, heavier ~500MB)
 *
 * Option 3: Sherpa-ONNX (Good balance, ONNX runtime based)
 *
 * To integrate: implement OfflineSTTProvider interface with chosen backend.
 */
