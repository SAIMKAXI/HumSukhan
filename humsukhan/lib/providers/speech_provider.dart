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

  final Map<String, ModelDownloadProgress> _downloadProgress = {};
  bool _isDownloading = false;

  SpeechProvider() {
    _sttProvider = EnhancedSpeechProvider();
    _ttsProvider = RealTtsProvider();
    _modelManager = ModelManager.instance;
  }

  EnhancedSpeechProvider get sttProvider => _sttProvider;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;
  LanguageResult? get detectedLanguage => _detectedLanguage;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;

  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;
  bool get isLiveStt => _currentMode != STTMode.none && _currentMode != STTMode.demo;

  bool get isDownloading => _isDownloading;
  Map<String, ModelDownloadProgress> get downloadProgress => Map.unmodifiable(_downloadProgress);

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

  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_isInitialized) return;

    _currentLanguage = preferredLanguage;
    await _modelManager.initialize();

    _downloadSubscription = _modelManager.onProgress.listen((progress) {
      _downloadProgress[progress.language] = progress;
      _isDownloading = _downloadProgress.values.any(
        (p) => p.status == DownloadStatus.downloading,
      );
      notifyListeners();
    });

    await _sttProvider.initialize(preferredLanguage: preferredLanguage);
    await _ttsProvider.initialize();

    _currentMode = _sttProvider.currentMode;
    _isInitialized = true;
    notifyListeners();
  }

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

  Future<void> stopListening() async {
    await _sttProvider.stopListening();
    _sttSubscription?.cancel();
    notifyListeners();
  }

  Future<void> switchToOfflineStreamingMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.sherpaStreaming, language: language);
    _currentMode = STTMode.sherpaStreaming;
    _currentLanguage = language;
    notifyListeners();
  }

  Future<void> switchToOfflineBatchMode({String language = 'Urdu'}) async {
    await _sttProvider.switchMode(STTMode.sherpaBatch, language: language);
    _currentMode = STTMode.sherpaBatch;
    _currentLanguage = language;
    notifyListeners();
  }

  Future<void> switchToOnlineMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.platform, language: language);
    _currentMode = STTMode.platform;
    _currentLanguage = language;
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    await _sttProvider.switchLanguage(language);
    _currentLanguage = language;
    _currentMode = _sttProvider.currentMode;
    notifyListeners();
  }

  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();
  List<String> get readyLanguages => _modelManager.readyLanguages;

  bool isModelReady(String language) {
    return _modelManager.isModelReady(language);
  }

  ModelStatus? getModelStatus(String language) {
    return _modelManager.statuses[language];
  }

  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) {
      await _sttProvider.initialize(preferredLanguage: language);
      _currentMode = _sttProvider.currentMode;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success) {
      await _sttProvider.initialize(preferredLanguage: _currentLanguage);
      _currentMode = _sttProvider.currentMode;
      notifyListeners();
    }
    return success;
  }

  Stream<SpeechResultEvent> get onResult => _sttProvider.onResult;

  /// Speak one message without allowing the live STT pipeline to hear the
  /// generated audio. When a conversation is active, STT is paused for the
  /// full duration of TTS and then resumed with the same language/mode.
  Future<void> speak(String text, {String language = 'English'}) async {
    final value = text.trim();
    if (value.isEmpty) return;

    final wasListening = _sttProvider.isListening;
    final resumeLanguage = _currentLanguage;

    if (wasListening) {
      await _sttProvider.stopListening();
    }

    _isSpeaking = true;
    _lastSpokenText = value;
    notifyListeners();

    try {
      await _ttsProvider.speak(value, language: language);
    } finally {
      _isSpeaking = false;
      notifyListeners();
      if (wasListening) {
        await _sttProvider.startListening(language: resumeLanguage);
        _currentMode = _sttProvider.currentMode;
        notifyListeners();
      }
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsProvider.stop();
    _isSpeaking = false;
    notifyListeners();
  }

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
