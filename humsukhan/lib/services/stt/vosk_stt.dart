import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'model_manager.dart';

/// Sherpa-ONNX based offline STT provider.
///
/// Supports two modes:
/// 1. **Streaming mode** (English): Real-time captioning using Zipformer model
/// 2. **Batch mode** (Urdu/Hindi): Process audio segments using Dolphin CTC model
///
/// The model manager handles downloading and storing language models.
class SherpaSTTProvider {
  final StreamController<SherpaSTTResult> _controller =
      StreamController<SherpaSTTResult>.broadcast();

  final ModelManager _modelManager = ModelManager.instance;

  bool _initialized = false;
  bool _listening = false;
  bool _available = false;
  String _currentLanguage = 'English';
  STTMode _currentMode = STTMode.none;

  // Sherpa-ONNX native objects
  sherpa_onnx.OnlineRecognizer? _onlineRecognizer;
  sherpa_onnx.OnlineStream? _onlineStream;
  sherpa_onnx.OfflineRecognizer? _offlineRecognizer;
  sherpa_onnx.OfflineStream? _offlineStream;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioSubscription;
  final int _sampleRate = 16000;

  // Sentence tracking
  String _lastFinalText = '';

  Stream<SherpaSTTResult> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _available;
  bool get isInitialized => _initialized;
  String get currentLanguage => _currentLanguage;
  STTMode get currentMode => _currentMode;
  bool get isStreaming => _currentMode == STTMode.sherpaStreaming;
  bool get isBatch => _currentMode == STTMode.sherpaBatch;

  /// Initialize the Sherpa-ONNX STT engine.
  Future<bool> initialize({String language = 'English'}) async {
    if (_initialized) return _available;

    try {
      // Initialize sherpa-onnx bindings
      sherpa_onnx.initBindings();

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission denied');
        _available = false;
        _initialized = true;
        return false;
      }

      // Initialize model manager
      await _modelManager.initialize();

      // Check if we have a model for the requested language
      _available = _modelManager.isModelReady(language);
      _currentLanguage = language;

      if (_available) {
        // Determine mode based on model type
        final model = _modelManager.getBestModel(language);
        if (model != null && model.isStreaming) {
          _currentMode = STTMode.sherpaStreaming;
          await _initStreamingRecognizer(model);
        } else {
          _currentMode = STTMode.sherpaBatch;
          await _initBatchRecognizer(model);
        }
        debugPrint('Sherpa-ONNX STT initialized. Mode: $_currentMode, Language: $language');
      } else {
        debugPrint('Sherpa-ONNX not available for $language. Model needs to be downloaded.');
        _currentMode = STTMode.none;
      }

      _initialized = true;
      return _available;
    } catch (e) {
      debugPrint('Sherpa-ONNX initialization failed: $e');
      _available = false;
      _initialized = true;
      return false;
    }
  }

  /// Initialize streaming recognizer (English).
  Future<void> _initStreamingRecognizer(LanguageModel model) async {
    final modelPath = await _modelManager.getModelPath(_currentLanguage);
    if (modelPath == null) {
      debugPrint('Model path not available for $_currentLanguage');
      return;
    }

    final config = sherpa_onnx.OnlineRecognizerConfig(
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
    );

    _onlineRecognizer = sherpa_onnx.OnlineRecognizer(config);
    _onlineStream = _onlineRecognizer?.createStream();
    debugPrint('Streaming recognizer initialized for $_currentLanguage');
  }

  /// Initialize batch recognizer (Urdu).
  Future<void> _initBatchRecognizer(LanguageModel? model) async {
    if (model == null) return;

    final modelPath = await _modelManager.getModelPath(_currentLanguage);
    if (modelPath == null) {
      debugPrint('Model path not available for $_currentLanguage');
      return;
    }

    final config = sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        paraformer: sherpa_onnx.OfflineParaformerModelConfig(
          model: '$modelPath/${model.modelFile ?? 'model.int8.onnx'}',
        ),
        tokens: '$modelPath/${model.tokens}',
      ),
    );

    _offlineRecognizer = sherpa_onnx.OfflineRecognizer(config);
    debugPrint('Batch recognizer initialized for $_currentLanguage');
  }

  /// Switch to a different language.
  Future<bool> switchLanguage(String language) async {
    if (_listening) {
      await stopListening();
    }

    _currentLanguage = language;
    _available = _modelManager.isModelReady(language);

    if (_available) {
      final model = _modelManager.getBestModel(language);
      if (model != null && model.isStreaming) {
        _currentMode = STTMode.sherpaStreaming;
        await _initStreamingRecognizer(model);
      } else {
        _currentMode = STTMode.sherpaBatch;
        await _initBatchRecognizer(model);
      }
    } else {
      _currentMode = STTMode.none;
    }

    return _available;
  }

  /// Start listening for speech.
  Future<void> startListening({String language = 'English'}) async {
    if (!_available || !_modelManager.isModelReady(language)) {
      debugPrint('Cannot start listening: model not ready for $language');
      return;
    }

    _currentLanguage = language;
    _listening = true;
    _lastFinalText = '';

    try {
      if (_currentMode == STTMode.sherpaStreaming) {
        await _startStreamingMode();
      } else if (_currentMode == STTMode.sherpaBatch) {
        await _startBatchMode();
      }
    } catch (e) {
      debugPrint('Failed to start listening: $e');
      _listening = false;
    }
  }

  /// Start streaming mode (real-time captions).
  Future<void> _startStreamingMode() async {
    debugPrint('Starting streaming mode for $_currentLanguage');

    if (_onlineRecognizer == null || _onlineStream == null) {
      debugPrint('Online recognizer not initialized');
      return;
    }

    // Check for microphone permission and start recording
    if (await _audioRecorder.hasPermission()) {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      _audioSubscription = stream.listen(
        (data) {
          if (!_listening) return;

          // Convert int samples to float32
          final samplesFloat32 = _convertBytesToFloat32(Uint8List.fromList(data));

          // Feed audio to recognizer
          _onlineStream!.acceptWaveform(
            samples: samplesFloat32,
            sampleRate: _sampleRate,
          );

          // Decode
          while (_onlineRecognizer!.isReady(_onlineStream!)) {
            _onlineRecognizer!.decode(_onlineStream!);
          }

          // Get result
          final result = _onlineRecognizer!.getResult(_onlineStream!);
          final text = result.text;

          if (text.isNotEmpty && text != _lastFinalText) {
            // Check for endpoint (sentence complete)
            if (_onlineRecognizer!.isEndpoint(_onlineStream!)) {
              _onlineRecognizer!.reset(_onlineStream!);
              _lastFinalText = text;

              // Emit final result
              _controller.add(SherpaSTTResult(
                text: text,
                isFinal: true,
                confidence: 0.9,
                isStreaming: true,
              ));
            } else {
              // Emit partial result
              _controller.add(SherpaSTTResult(
                text: text,
                isFinal: false,
                confidence: 0.7,
                isStreaming: true,
              ));
            }
          }
        },
        onDone: () {
          debugPrint('Audio stream stopped');
        },
        onError: (e) {
          debugPrint('Audio stream error: $e');
        },
      );
    }
  }

  /// Start batch mode (process audio segments).
  Future<void> _startBatchMode() async {
    debugPrint('Starting batch mode for $_currentLanguage');

    // For batch mode, we record a chunk and process it
    if (await _audioRecorder.hasPermission()) {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      final List<int> audioBuffer = [];

      _audioSubscription = stream.listen(
        (data) {
          if (!_listening) return;
          audioBuffer.addAll(data);

          // Process every ~3 seconds of audio
          if (audioBuffer.length >= 16000 * 3 * 2) {
            _processBatchChunk(Uint8List.fromList(audioBuffer));
            audioBuffer.clear();
          }
        },
        onDone: () {
          // Process remaining audio
          if (audioBuffer.isNotEmpty) {
            _processBatchChunk(Uint8List.fromList(audioBuffer));
          }
        },
      );
    }
  }

  /// Process a chunk of audio in batch mode.
  void _processBatchChunk(Uint8List audioData) {
    if (_offlineRecognizer == null) return;

    try {
      final samplesFloat32 = _convertBytesToFloat32(audioData);

      final stream = _offlineRecognizer!.createStream();
      stream.acceptWaveform(
        samples: samplesFloat32,
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
          isStreaming: false,
        ));
      }
    } catch (e) {
      debugPrint('Batch processing error: $e');
    }
  }

  /// Stop listening.
  Future<void> stopListening() async {
    _listening = false;
    _audioSubscription?.cancel();
    _audioSubscription = null;

    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }

    // Reset streams for next session
    if (_onlineRecognizer != null && _onlineStream != null) {
      _onlineStream!.free();
      _onlineStream = _onlineRecognizer!.createStream();
    }
  }

  /// Toggle listening on/off.
  Future<void> toggle({String language = 'English'}) async {
    if (_listening) {
      await stopListening();
    } else {
      await startListening(language: language);
    }
  }

  /// Convert PCM16 bytes to Float32 samples.
  Float32List _convertBytesToFloat32(Uint8List bytes) {
    final int16List = Int16List.view(bytes.buffer);
    final float32List = Float32List(int16List.length);
    for (int i = 0; i < int16List.length; i++) {
      float32List[i] = int16List[i] / 32768.0;
    }
    return float32List;
  }

  /// Get the best available model for a language.
  LanguageModel? getModelForLanguage(String language) {
    return _modelManager.getBestModel(language);
  }

  /// Get the status of a language model.
  ModelStatus? getModelStatus(String language) {
    return _modelManager.statuses[language];
  }

  /// Download a model for a language.
  Future<bool> downloadModel(String language) async {
    return await _modelManager.downloadModel(language);
  }

  /// Get list of languages with ready models.
  List<String> get readyLanguages => _modelManager.readyLanguages;

  /// Get list of all available languages.
  List<String> get availableLanguages => _modelManager.availableLanguages;

  void dispose() {
    _audioSubscription?.cancel();
    _onlineStream?.free();
    _onlineRecognizer?.free();
    _offlineStream?.free();
    _offlineRecognizer?.free();
    _audioRecorder.dispose();
    _controller.close();
    _modelManager.dispose();
  }
}

/// Result from Sherpa-ONNX STT.
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

/// STT mode enumeration.
enum STTMode {
  none,
  sherpaStreaming, // Real-time streaming (English)
  sherpaBatch,     // Batch processing (Urdu/Hindi)
  platform,        // Platform-native STT (requires internet)
  demo,            // Legacy - no longer used
}
