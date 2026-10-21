import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'cloud_chunk_stt.dart' show UtteranceSegmenter;
import 'model_manager.dart';
import 'offline_batch_worker.dart';

/// Sherpa-ONNX based offline STT provider.
///
/// English uses streaming Zipformer. Urdu uses Whisper held to Urdu, which
/// recognizes one sentence at a time after the speaker pauses. The provider
/// never reports listening until the recorder and recognizer have both
/// started successfully.
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
  OfflineBatchWorker? _batchWorker;
  UtteranceSegmenter? _segmenter;
  StreamSubscription<List<int>>? _audioSubscription;
  final int _sampleRate = 16000;
  String _lastFinalText = '';

  // Lightweight voice-activity gate used by the streaming path. It learns a
  // quiet ambient-noise floor and prevents very low-energy background noise
  // from dominating recognition while still passing short speech bursts.
  double _noiseFloorRms = 0.0;
  bool _speechActive = false;
  DateTime? _lastVoiceAt;

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

  static sherpa_onnx.OnlineRecognizerConfig streamingConfig(LanguageModel model, String modelPath) =>
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
      );

  static WhisperModelFiles whisperFiles(LanguageModel model, String modelPath) => WhisperModelFiles(
        encoder: '$modelPath/${model.encoder}',
        decoder: '$modelPath/${model.decoder}',
        tokens: '$modelPath/${model.tokens}',
        language: model.whisperLanguage,
      );

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
      _onlineRecognizer = sherpa_onnx.OnlineRecognizer(streamingConfig(model, modelPath));
      _onlineStream = _onlineRecognizer!.createStream();
    } else {
      _currentMode = STTMode.sherpaBatch;
      _batchWorker = await OfflineBatchWorker.start(whisperFiles(model, modelPath));
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

      _listening = true;
      _lastFinalText = '';
        _noiseFloorRms = 0.0;
      _speechActive = false;
      _lastVoiceAt = null;

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
        final worker = _batchWorker;
        if (worker == null) {
          _listening = false;
          return;
        }
        final segmenter = UtteranceSegmenter(onUtterance: (pcm) => unawaited(_transcribeUtterance(worker, pcm)));
        _segmenter = segmenter;
        final stream = await _audioRecorder.startStream(config);
        _audioSubscription = stream.listen(
          (data) {
            if (_listening) segmenter.add(Uint8List.fromList(data));
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
    }
  }

  double _rms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    return math.sqrt(energy / samples.length);
  }

  Float32List _silenceLike(Float32List samples) {
    return Float32List(samples.length);
  }

  void _handleStreamingAudio(List<int> data) {
    if (!_listening || _onlineRecognizer == null || _onlineStream == null) return;
    try {
      final samples = _convertBytesToFloat32(Uint8List.fromList(data));
      final now = DateTime.now();
      final rms = _rms(samples);

      // Learn the ambient floor only from relatively quiet frames. This keeps
      // the gate adaptive without allowing speech to permanently raise it.
      if (!_speechActive && rms < 0.05) {
        _noiseFloorRms = _noiseFloorRms == 0.0
            ? rms
            : (_noiseFloorRms * 0.94) + (rms * 0.06);
      }

      final threshold = math.max(0.006, _noiseFloorRms * 1.8);
      final hasVoiceEnergy = rms >= threshold && rms >= 0.006;
      if (hasVoiceEnergy) {
        _speechActive = true;
        _lastVoiceAt = now;
      } else if (_speechActive &&
          _lastVoiceAt != null &&
          now.difference(_lastVoiceAt!).inMilliseconds >= 1200) {
        _speechActive = false;
      }

      // Continue feeding the recognizer with silence during quiet periods so
      // endpoint detection can close the previous utterance cleanly.
      final gatedSamples = hasVoiceEnergy || _speechActive
          ? samples
          : _silenceLike(samples);

      _onlineStream!.acceptWaveform(
        samples: gatedSamples,
        sampleRate: _sampleRate,
      );
      while (_onlineRecognizer!.isReady(_onlineStream!)) {
        _onlineRecognizer!.decode(_onlineStream!);
      }
      final result = _onlineRecognizer!.getResult(_onlineStream!);
      final text = result.text;
      if (text.isEmpty || text == _lastFinalText) return;
      if (_onlineRecognizer!.isEndpoint(_onlineStream!)) {
        _onlineRecognizer!.reset(_onlineStream!);
        _lastFinalText = text;
        _speechActive = false;
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

  Future<void> _transcribeUtterance(OfflineBatchWorker worker, Uint8List pcm) async {
    final text = await worker.transcribe(pcm);
    if (text.isEmpty || _controller.isClosed) return;
    _controller.add(SherpaSTTResult(text: text, isFinal: true, confidence: 0.85));
  }

  Future<void> stopListening() async {
    // Transcribe what was still being said when listening stopped.
    _segmenter?.flush();
    _segmenter = null;

    _listening = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _safeStopRecorder();

    if (_onlineRecognizer != null) {
      _onlineStream?.free();
      _onlineStream = _onlineRecognizer!.createStream();
    }
    _speechActive = false;
    _lastVoiceAt = null;
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

  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];
  Future<bool> downloadModel(String language) => _modelManager.downloadModel(language);
  List<String> get readyLanguages => _modelManager.readyLanguages;
  List<String> get availableLanguages => _modelManager.availableLanguages;

  void _releaseRecognizers() {
    _onlineStream?.free();
    _onlineRecognizer?.free();
    _batchWorker?.dispose();
    _onlineStream = null;
    _onlineRecognizer = null;
    _batchWorker = null;
  }

  /// A model was downloaded or deleted: load it, or let go of it, on the
  /// next start instead of keeping the state found at startup.
  Future<void> reloadModels() async {
    if (_listening) await stopListening();
    _releaseRecognizers();
    _available = _modelManager.isModelReady(_currentLanguage);
    _currentMode = STTMode.none;
  }

  void dispose() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _safeStopRecorder();
    _segmenter = null;
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

/// How speech is being recognized. [cloudBatch] is the recorded-utterance
/// cloud backup, used when the device recognizer lacks the language.
enum STTMode { none, sherpaStreaming, sherpaBatch, platform, cloudBatch }
