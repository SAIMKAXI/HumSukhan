import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'model_manager.dart';

/// Sherpa-ONNX based offline STT provider.
///
/// English uses streaming Zipformer. Urdu/Hindi uses the Dolphin CTC
/// offline recognizer. The provider never reports listening until the
/// recorder and recognizer have both started successfully.
class SherpaSTTProvider {
  final StreamController<SherpaSTTResult> _controller =
      StreamController<SherpaSTTResult>.broadcast();
  final ModelManager _modelManager = ModelManager.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _initialized = false;
  bool _listening = false;
  bool _available = false;
  String _currentLanguage = 'English';
  STTMode _currentMode = STTMode.none;
  sherpa_onnx.OnlineRecognizer? _onlineRecognizer;
  sherpa_onnx.OnlineStream? _onlineStream;
  sherpa_onnx.OfflineRecognizer? _offlineRecognizer;
  StreamSubscription<List<int>>? _audioSubscription;
  final int _sampleRate = 16000;
  String _lastFinalText = '';
  final List<int> _batchAudioBuffer = <int>[];

  Stream<SherpaSTTResult> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _available;
  bool get isInitialized => _initialized;
  String get currentLanguage => _currentLanguage;
  STTMode get currentMode => _currentMode;
  bool get isStreaming => _currentMode == STTMode.sherpaStreaming;
  bool get isBatch => _currentMode == STTMode.sherpaBatch;

  Future<bool> initialize({String language = 'English'}) async {
    if (_initialized) return _available;
    try {
      sherpa_onnx.initBindings();
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _initialized = true;
        return false;
      }
      await _modelManager.initialize();
      _currentLanguage = language;
      _available = _modelManager.isModelReady(language);
      if (_available) {
        await _configureForLanguage(language);
      } else {
        _currentMode = STTMode.none;
      }
      _initialized = true;
      return _available;
    } catch (e) {
      debugPrint('Sherpa-ONNX initialization failed: $e');
      _available = false;
      _currentMode = STTMode.none;
      _initialized = true;
      return false;
    }
  }

  Future<void> _configureForLanguage(String language) async {
    _releaseRecognizers();
    final model = _modelManager.getBestModel(language);
    if (model == null) {
      _available = false;
      _currentMode = STTMode.none;
      return;
    }
    final modelPath = await _modelManager.getModelPath(language);
    if (modelPath == null) {
      _available = false;
      _currentMode = STTMode.none;
      return;
    }

    _currentLanguage = language;
    if (model.isStreaming) {
      _currentMode = STTMode.sherpaStreaming;
      _onlineRecognizer = sherpa_onnx.OnlineRecognizer(
        sherpa_onnx.OnlineRecognizerConfig(
          model: sherpa_onnx.OnlineModelConfig(
            transducer: sherpa_onnx.OnlineTransducerModelConfig(
              encoder: '$modelPath/${model.encoder}',
              decoder: '$modelPath/${model.decoder}',
              joiner: '$modelPath/${model.joiner}',
            ),
            tokens: '$modelPath/${model.tokens}',
          ),
          enableEndpoint: true,
          ruleFsts: '',
        ),
      );
      _onlineStream = _onlineRecognizer!.createStream();
    } else {
      // Dolphin is a CTC model. Do not configure it as Paraformer.
      _currentMode = STTMode.sherpaBatch;
      _offlineRecognizer = sherpa_onnx.OfflineRecognizer(
        sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            dolphin: sherpa_onnx.OfflineDolphinModelConfig(
              model: '$modelPath/${model.modelFile ?? 'model.int8.onnx'}',
            ),
            tokens: '$modelPath/${model.tokens}',
          ),
        ),
      );
    }
    _available = true;
  }

  Future<bool> switchLanguage(String language) async {
    final wasListening = _listening;
    if (wasListening) await stopListening();
    _available = _modelManager.isModelReady(language);
    if (_available) {
      try {
        await _configureForLanguage(language);
      } catch (e) {
        debugPrint('STT language switch failed: $e');
        _available = false;
        _currentMode = STTMode.none;
      }
    } else {
      _currentLanguage = language;
      _currentMode = STTMode.none;
    }
    if (wasListening && _available) await startListening(language: language);
    return _available;
  }

  Future<void> startListening({String language = 'English'}) async {
    if (_listening) return;
    if (language != _currentLanguage || !_available) {
      final ok = await switchLanguage(language);
      if (!ok) return;
    }
    if (!_available) return;

    try {
      if (!await _audioRecorder.hasPermission()) return;
      final config = const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Mark the provider active before subscribing so the first audio
      // callback cannot be discarded by the _listening guard.
      _listening = true;
      _lastFinalText = '';
      _batchAudioBuffer.clear();

      if (_currentMode == STTMode.sherpaStreaming) {
        if (_onlineRecognizer == null || _onlineStream == null) {
          _listening = false;
          return;
        }
        final stream = await _audioRecorder.startStream(config);
        _audioSubscription = stream.listen(
          _handleStreamingAudio,
          onError: (e) => debugPrint('STT audio error: $e'),
        );
      } else if (_currentMode == STTMode.sherpaBatch) {
        if (_offlineRecognizer == null) {
          _listening = false;
          return;
        }
        final stream = await _audioRecorder.startStream(config);
        _audioSubscription = stream.listen(
          (data) {
            if (!_listening) return;
            _batchAudioBuffer.addAll(data);
            if (_batchAudioBuffer.length >= _sampleRate * 3 * 2) {
              final chunk = Uint8List.fromList(_batchAudioBuffer);
              _batchAudioBuffer.clear();
              _processBatchChunk(chunk);
            }
          },
          onError: (e) => debugPrint('STT batch audio error: $e'),
        );
      } else {
        _listening = false;
        return;
      }
    } catch (e) {
      debugPrint('Failed to start listening: $e');
      _listening = false;
      await _safeStopRecorder();
      _batchAudioBuffer.clear();
    }
  }

  void _handleStreamingAudio(List<int> data) {
    if (!_listening || _onlineRecognizer == null || _onlineStream == null) return;
    try {
      final samples = _convertBytesToFloat32(Uint8List.fromList(data));
      _onlineStream!.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      while (_onlineRecognizer!.isReady(_onlineStream!)) {
        _onlineRecognizer!.decode(_onlineStream!);
      }
      final result = _onlineRecognizer!.getResult(_onlineStream!);
      final text = result.text;
      if (text.isEmpty || text == _lastFinalText) return;
      if (_onlineRecognizer!.isEndpoint(_onlineStream!)) {
        _onlineRecognizer!.reset(_onlineStream!);
        _lastFinalText = text;
        _controller.add(SherpaSTTResult(
          text: text,
          isFinal: true,
          confidence: 0.9,
          isStreaming: true,
        ));
      } else {
        _controller.add(SherpaSTTResult(
          text: text,
          confidence: 0.7,
          isStreaming: true,
        ));
      }
    } catch (e) {
      debugPrint('Streaming decode error: $e');
    }
  }

  void _processBatchChunk(Uint8List audioData) {
    if (!_listening || _offlineRecognizer == null || audioData.isEmpty) return;
    try {
      final stream = _offlineRecognizer!.createStream();
      stream.acceptWaveform(
        samples: _convertBytesToFloat32(audioData),
        sampleRate: _sampleRate,
      );
      _offlineRecognizer!.decode(stream);
      final result = _offlineRecognizer!.getResult(stream);
      stream.free();
      if (result.text.isNotEmpty) {
        _controller.add(SherpaSTTResult(
          text: result.text,
          isFinal: true,
          confidence: 0.85,
        ));
      }
    } catch (e) {
      debugPrint('Batch processing error: $e');
    }
  }

  Future<void> stopListening() async {
    // Flush the final partial batch before marking the provider inactive.
    // Previously the final <3 second chunk was discarded on every stop.
    if (_currentMode == STTMode.sherpaBatch && _batchAudioBuffer.isNotEmpty) {
      final finalChunk = Uint8List.fromList(_batchAudioBuffer);
      _batchAudioBuffer.clear();
      _processBatchChunk(finalChunk);
    }

    _listening = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _safeStopRecorder();

    if (_onlineRecognizer != null) {
      _onlineStream?.free();
      _onlineStream = _onlineRecognizer!.createStream();
    }
  }

  Future<void> _safeStopRecorder() async {
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error stopping STT recorder: $e');
    }
  }

  Future<void> toggle({String language = 'English'}) async {
    if (_listening) {
      await stopListening();
    } else {
      await startListening(language: language);
    }
  }

  Float32List _convertBytesToFloat32(Uint8List bytes) {
    final length = bytes.lengthInBytes - (bytes.lengthInBytes % 2);
    final view = Int16List.view(bytes.buffer, bytes.offsetInBytes, length ~/ 2);
    final result = Float32List(view.length);
    for (var i = 0; i < view.length; i++) {
      result[i] = view[i] / 32768.0;
    }
    return result;
  }

  LanguageModel? getModelForLanguage(String language) => _modelManager.getBestModel(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];
  Future<bool> downloadModel(String language) => _modelManager.downloadModel(language);
  List<String> get readyLanguages => _modelManager.readyLanguages;
  List<String> get availableLanguages => _modelManager.availableLanguages;

  void _releaseRecognizers() {
    _onlineStream?.free();
    _onlineRecognizer?.free();
    _offlineRecognizer?.free();
    _onlineStream = null;
    _onlineRecognizer = null;
    _offlineRecognizer = null;
  }

  void dispose() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _safeStopRecorder();
    _batchAudioBuffer.clear();
    _releaseRecognizers();
    _controller.close();
  }
}

class SherpaSTTResult {
  final String text;
  final bool isFinal;
  final double confidence;
  final bool isStreaming;

  const SherpaSTTResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
    this.isStreaming = false,
  });
}

enum STTMode { none, sherpaStreaming, sherpaBatch, platform, demo }
