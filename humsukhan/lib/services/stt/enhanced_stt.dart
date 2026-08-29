import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'vosk_stt.dart';
import 'model_manager.dart';

// Re-export STTMode and related types from vosk_stt.dart
export 'vosk_stt.dart' show STTMode;

/// Enhanced Speech-to-Text provider with hybrid offline/online architecture.
///
/// Priority order:
/// 1. Sherpa-ONNX Streaming (English) - Real-time captions, offline
/// 2. Sherpa-ONNX Batch (Urdu/Hindi) - Short delay, offline
/// 3. Platform STT (Google/Apple) - Requires internet
/// 4. Demo mode - Fake phrases for testing
///
/// The provider automatically selects the best available mode based on:
/// - Which models are downloaded
/// - The selected language
/// - Network availability
class EnhancedSpeechProvider {
  final SpeechToText _platformSTT = SpeechToText();
  final SherpaSTTProvider _sherpaSTT = SherpaSTTProvider();
  final StreamController<SpeechResultEvent> _controller =
      StreamController<SpeechResultEvent>.broadcast();

  final ModelManager _modelManager = ModelManager.instance;

  bool _initialized = false;
  bool _listening = false;
  bool _platformAvailable = false;
  bool _sherpaAvailable = false;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';

  Function(double progress, String status)? onModelDownloadProgress;

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _platformAvailable || _sherpaAvailable;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;
  bool get isSherpaAvailable => _sherpaAvailable;
  bool get isPlatformAvailable => _platformAvailable;

  // Convenience getters for UI
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;

  /// Initialize both STT engines.
  Future<bool> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return isAvailable;

    _currentLanguage = preferredLanguage;

    // Initialize model manager
    await _modelManager.initialize();

    // Try Sherpa-ONNX offline STT first (primary)
    try {
      _sherpaAvailable = await _sherpaSTT.initialize(language: preferredLanguage);
      debugPrint('Sherpa STT available: $_sherpaAvailable');
    } catch (e) {
      debugPrint('Sherpa STT init failed: $e');
      _sherpaAvailable = false;
    }

    // Try platform STT as fallback (requires internet on Android)
    try {
      _platformAvailable = await _platformSTT.initialize(
        onStatus: _onPlatformStatus,
        onError: (error) {
          debugPrint('Platform STT error: ${error.errorMsg}');
          if (_listening && (error.errorMsg == 'no_match' || error.errorMsg == 'speech_timeout')) {
            _platformSTT.listen();
          }
        },
      );
      debugPrint('Platform STT available: $_platformAvailable');
    } catch (e) {
      debugPrint('Platform STT init failed: $e');
      _platformAvailable = false;
    }

    _initialized = true;

    // Set initial mode based on what's available
    _updateModeForLanguage(preferredLanguage);

    debugPrint('STT initialized - Mode: $_currentMode, Language: $_currentLanguage');
    return isAvailable;
  }

  /// Update the current mode based on language and available models.
  void _updateModeForLanguage(String language) {
    if (_sherpaAvailable && _modelManager.isModelReady(language)) {
      final model = _modelManager.getBestModel(language);
      if (model != null && model.isStreaming) {
        _currentMode = STTMode.sherpaStreaming;
      } else {
        _currentMode = STTMode.sherpaBatch;
      }
    } else if (_platformAvailable) {
      _currentMode = STTMode.platform;
    } else {
      _currentMode = STTMode.demo;
    }
  }

  void _onPlatformStatus(String status) {
    debugPrint('Platform STT status: $status');
    if (status == 'notListening' && _listening) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_listening && _currentMode == STTMode.platform) {
          _platformSTT.listen();
        }
      });
    }
  }

  /// Start listening with the best available engine for the current language.
  Future<void> startListening({String language = 'English'}) async {
    if (!_initialized) {
      await initialize(preferredLanguage: language);
    }

    _currentLanguage = language;
    _listening = true;

    // Update mode for the selected language
    _updateModeForLanguage(language);

    switch (_currentMode) {
      case STTMode.sherpaStreaming:
        await _startSherpaStreaming(language);
        break;
      case STTMode.sherpaBatch:
        await _startSherpaBatch(language);
        break;
      case STTMode.platform:
        await _startPlatformListening(language);
        break;
      case STTMode.demo:
        _startDemoMode();
        break;
      case STTMode.none:
        _startDemoMode();
        break;
    }

    debugPrint('Started listening in $_currentMode mode for $language');
  }

  /// Start Sherpa streaming mode (real-time English captions).
  Future<void> _startSherpaStreaming(String language) async {
    _sherpaSTT.onResult.listen((result) {
      _controller.add(SpeechResultEvent(
        text: result.text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(result.text),
        isLive: true,
        mode: STTMode.sherpaStreaming,
      ));
    });

    await _sherpaSTT.startListening(language: language);
  }

  /// Start Sherpa batch mode (Urdu/Hindi with short delay).
  Future<void> _startSherpaBatch(String language) async {
    _sherpaSTT.onResult.listen((result) {
      _controller.add(SpeechResultEvent(
        text: result.text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(result.text),
        isLive: true,
        mode: STTMode.sherpaBatch,
      ));
    });

    await _sherpaSTT.startListening(language: language);
  }

  /// Start platform-native STT (requires internet on Android).
  Future<void> _startPlatformListening(String language) async {
    _platformSTT.listen(
      onResult: _onPlatformResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: _getLocaleId(language),
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _onPlatformResult(SpeechRecognitionResult result) {
    _controller.add(SpeechResultEvent(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.confidence,
      language: _detectLanguage(result.recognizedWords),
      isLive: true,
      mode: STTMode.platform,
    ));
  }

  void _startDemoMode() {
    // No-op: demo/simulated mode is disabled.
    // Speech recognition requires either:
    // 1. A downloaded Sherpa-ONNX model (offline)
    // 2. Platform STT (requires internet)
    // The UI should show 'Unavailable' when neither is available.
    debugPrint('Demo mode disabled. No simulated captions will be generated.');
  }

  /// Stop listening.
  Future<void> stopListening() async {
    _listening = false;

    if (_currentMode == STTMode.platform) {
      await _platformSTT.stop();
    } else if (_currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch) {
      await _sherpaSTT.stopListening();
    }
  }

  /// Switch STT mode manually.
  Future<void> switchMode(STTMode mode, {String language = 'English'}) async {
    if (_listening) {
      await stopListening();
    }
    _currentMode = mode;
    _currentLanguage = language;
    if (_listening) {
      await startListening(language: language);
    }
  }

  /// Switch to a different language.
  Future<void> switchLanguage(String language) async {
    if (_listening) {
      await stopListening();
    }
    _currentLanguage = language;

    // Update Sherpa mode for new language
    await _sherpaSTT.switchLanguage(language);

    if (_listening) {
      await startListening(language: language);
    }
  }

  /// Download a Sherpa-ONNX model for offline use.
  Future<bool> downloadModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) {
      // Re-initialize Sherpa with new model
      _sherpaAvailable = await _sherpaSTT.initialize(language: language);
    }
    return success;
  }

  /// Check if a model is downloaded for a language.
  bool isModelReady(String language) {
    return _modelManager.isModelReady(language);
  }

  /// Get model status for a language.
  ModelStatus? getModelStatus(String language) {
    return _modelManager.statuses[language];
  }

  /// Get all available languages.
  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();

  /// Get all languages with downloaded models.
  List<String> get readyLanguages => _modelManager.readyLanguages;

  /// Get the best mode label for UI display.
  String get sttModeLabel {
    switch (_currentMode) {
      case STTMode.sherpaStreaming:
        return 'Offline (Streaming)';
      case STTMode.sherpaBatch:
        return 'Offline (Batch)';
      case STTMode.platform:
        return 'Online (Google)';
      case STTMode.demo:
        return 'Demo Mode';
      case STTMode.none:
        return 'Unavailable';
    }
  }

  String _getLocaleId(String language) {
    switch (language.toLowerCase()) {
      case 'english':
        return 'en-US';
      case 'roman urdu':
      case 'urdu':
        return 'ur-PK';
      default:
        return 'en-US';
    }
  }

  String _detectLanguage(String text) {
    final urduScript = RegExp(r'[\u0600-\u06FF]');
    final romanUrduWords = ['kya', 'hai', 'mein', 'tum', 'aap', 'ho', 'se', 'ko'];
    if (urduScript.hasMatch(text)) return 'Urdu';
    if (romanUrduWords.any((w) => text.toLowerCase().contains(w))) return 'Roman Urdu';
    return 'English';
  }

  void dispose() {
    _platformSTT.cancel();
    _sherpaSTT.dispose();
    _controller.close();
    _modelManager.dispose();
  }
}

/// Speech result event with mode information.
class SpeechResultEvent {
  final String text;
  final bool isFinal;
  final double confidence;
  final String language;
  final bool isLive;
  final STTMode mode;

  const SpeechResultEvent({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
    this.language = 'English',
    this.isLive = true,
    this.mode = STTMode.platform,
  });

  bool get isOffline => mode == STTMode.sherpaStreaming || mode == STTMode.sherpaBatch;
  bool get isStreaming => mode == STTMode.sherpaStreaming;
  bool get isBatch => mode == STTMode.sherpaBatch;
  bool get isOnline => mode == STTMode.platform;
}
