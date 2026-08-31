import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';

abstract class TtsProvider {
  Future<bool> initialize();
  Future<void> speak(String text, {String language = 'English'});
  Future<void> stop();
  bool get isSpeaking;
  void dispose();
}

class RealTtsProvider implements TtsProvider {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  @override
  Future<bool> initialize() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setErrorHandler((msg) => _speaking = false);
      return true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      return false;
    }
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    _speaking = true;
    final locale = language.toLowerCase().contains('urdu') ? 'ur-PK' : 'en-US';
    await _tts.setLanguage(locale);
    await _tts.speak(text);
    while (_speaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  void dispose() {
    _tts.stop();
  }
}

/// Speech provider with hybrid STT support and model management.
///
/// Architecture:
/// - English: Streaming Zipformer (real-time captions, offline)
/// - Urdu/Hindi: Dolphin CTC (batch mode, offline)
/// - Fallback: Platform STT (requires internet) → Demo mode
class SpeechProvider extends ChangeNotifier {
  late final EnhancedSpeechProvider _sttProvider;
  late final TtsProvider _ttsProvider;
  late final ModelManager _modelManager;

  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _lastSpokenText = '';
  LanguageResult? _detectedLanguage;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';
  StreamSubscription<SpeechResultEvent>? _sttSubscription;
  StreamSubscription<ModelDownloadProgress>? _downloadSubscription;

  // Model download state
  final Map<String, ModelDownloadProgress> _downloadProgress = {};
  bool _isDownloading = false;

  SpeechProvider() {
    _sttProvider = EnhancedSpeechProvider();
    _ttsProvider = RealTtsProvider();
    _modelManager = ModelManager.instance;
  }

  // Getters
  EnhancedSpeechProvider get sttProvider => _sttProvider;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;
  LanguageResult? get detectedLanguage => _detectedLanguage;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;

  // Convenience mode checks
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;
  bool get isLiveStt => _currentMode != STTMode.none && _currentMode != STTMode.demo;

  // Model management
  bool get isDownloading => _isDownloading;
  Map<String, ModelDownloadProgress> get downloadProgress => Map.unmodifiable(_downloadProgress);

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

  /// Get a detailed description of the current STT mode.
  String get sttModeDescription {
    switch (_currentMode) {
      case STTMode.sherpaStreaming:
        return 'Real-time offline speech recognition using Sherpa-ONNX. No internet required.';
      case STTMode.sherpaBatch:
        return 'Offline speech recognition using Sherpa-ONNX. Short processing delay.';
      case STTMode.platform:
        return 'Online speech recognition using Google STT. Requires internet connection.';
      case STTMode.demo:
        return 'Demo mode with simulated captions. No actual speech recognition.';
      case STTMode.none:
        return 'Speech recognition unavailable. Please download a language model.';
    }
  }

  /// Initialize the speech provider.
  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_isInitialized) return;

    _currentLanguage = preferredLanguage;

    // Initialize model manager
    await _modelManager.initialize();

    // Listen for model download progress
    _downloadSubscription = _modelManager.onProgress.listen((progress) {
      _downloadProgress[progress.language] = progress;
      _isDownloading = _downloadProgress.values.any(
        (p) => p.status == DownloadStatus.downloading,
      );
      notifyListeners();
    });

    // Initialize STT provider
    await _sttProvider.initialize(preferredLanguage: preferredLanguage);
    await _ttsProvider.initialize();

    _currentMode = _sttProvider.currentMode;
    _isInitialized = true;
    notifyListeners();
  }

  /// Start listening for speech.
  Future<void> startListening({String language = 'English'}) async {
    _sttSubscription?.cancel();
    _sttSubscription = _sttProvider.onResult.listen((result) {
      _currentMode = result.mode;
      notifyListeners();
    });

    await _sttProvider.startListening(language: language);
    _currentMode = _sttProvider.currentMode;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Stop listening for speech.
  Future<void> stopListening() async {
    await _sttProvider.stopListening();
    _sttSubscription?.cancel();
    notifyListeners();
  }

  /// Switch to offline streaming mode (English).
  Future<void> switchToOfflineStreamingMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.sherpaStreaming, language: language);
    _currentMode = STTMode.sherpaStreaming;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Switch to offline batch mode (Urdu/Hindi).
  Future<void> switchToOfflineBatchMode({String language = 'Urdu'}) async {
    await _sttProvider.switchMode(STTMode.sherpaBatch, language: language);
    _currentMode = STTMode.sherpaBatch;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Switch to online mode (requires internet).
  Future<void> switchToOnlineMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.platform, language: language);
    _currentMode = STTMode.platform;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Switch to a different language.
  Future<void> switchLanguage(String language) async {
    await _sttProvider.switchLanguage(language);
    _currentLanguage = language;
    _currentMode = _sttProvider.currentMode;
    notifyListeners();
  }

  /// Get list of languages with offline models available for download.
  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();

  /// Get list of languages with downloaded models ready to use.
  List<String> get readyLanguages => _modelManager.readyLanguages;

  /// Check if a model is downloaded for a language.
  bool isModelReady(String language) {
    return _modelManager.isModelReady(language);
  }

  /// Get model status for a language.
  ModelStatus? getModelStatus(String language) {
    return _modelManager.statuses[language];
  }

  /// Download an offline model for a language.
  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) {
      // Re-initialize STT provider with new model
      await _sttProvider.initialize(preferredLanguage: language);
      _currentMode = _sttProvider.currentMode;
      notifyListeners();
    }
    return success;
  }

  /// Delete a downloaded model to free up space.
  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success) {
      // Re-initialize STT provider
      await _sttProvider.initialize(preferredLanguage: _currentLanguage);
      _currentMode = _sttProvider.currentMode;
      notifyListeners();
    }
    return success;
  }

  /// Get the speech-to-text result stream.
  Stream<SpeechResultEvent> get onResult => _sttProvider.onResult;

  /// Speak text using TTS.
  Future<void> speak(String text, {String language = 'English'}) async {
    _isSpeaking = true;
    _lastSpokenText = text;
    notifyListeners();
    await _ttsProvider.speak(text, language: language);
    _isSpeaking = false;
    notifyListeners();
  }

  /// Stop speaking.
  Future<void> stopSpeaking() async {
    await _ttsProvider.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  /// Detect the language of a text string.
  void detectLanguage(String text) {
    final urduScriptRegex = RegExp(r'[\u0600-\u06FF]');
    final romanUrduWords = ['kya', 'hai', 'mein', 'tum', 'aap', 'ho', 'se', 'ko', 'ka', 'ki', 'ke'];
    if (urduScriptRegex.hasMatch(text)) {
      _detectedLanguage = const LanguageResult(language: 'Urdu', confidence: 0.9, script: 'Arabic');
    } else if (romanUrduWords.any((w) => text.toLowerCase().contains(w))) {
      _detectedLanguage = const LanguageResult(language: 'Roman Urdu', confidence: 0.7, script: 'Latin');
    } else {
      _detectedLanguage = const LanguageResult(language: 'English', confidence: 0.85, script: 'Latin');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sttSubscription?.cancel();
    _downloadSubscription?.cancel();
    _sttProvider.dispose();
    _ttsProvider.dispose();
    _modelManager.dispose();
    super.dispose();
  }
}
