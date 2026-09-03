import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/models.dart';
import '../services/cloud_tts_service.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';

abstract class TtsProvider {
  Future<bool> initialize();
  Future<void> speak(String text, {String language = 'English'});
  Future<void> stop();
  bool get isSpeaking;
  void dispose();
}

class ResilientTtsProvider implements TtsProvider {
  final FlutterTts _native = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cloudCache = <String, Uint8List>{};
  bool _speaking = false;
  bool _initialized = false;
  int _speakGeneration = 0;
  static const int _maxCloudCacheEntries = 12;
  static const Duration _nativeSpeechTimeout = Duration(seconds: 90);

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      // Keep the device TTS engine warm. Local playback is the lowest-latency
      // path and avoids a network round-trip for English/Urdu/Hindi voices.
      await _native.awaitSpeakCompletion(true);
      await _native.setSpeechRate(0.5);
      await _native.setVolume(1.0);
      await _native.setPitch(1.0);
      // Touch the native voice catalog during warm-up so locale lookup and the
      // platform TTS engine are ready before the first user-triggered Speak.
      try { await _native.getVoices; } catch (_) {}
      _native.setStartHandler(() => _speaking = true);
      _native.setCompletionHandler(() => _speaking = false);
      _native.setCancelHandler(() => _speaking = false);
      _native.setErrorHandler((_) => _speaking = false);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      return false;
    }
  }

  Future<bool> warmUp() => initialize();

  String _deliveryLanguage(String language, String text) {
    final normalized = language.toLowerCase().trim();
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hindi';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'urdu';
    const romanUrdu = {
      'aap', 'ap', 'aapko', 'aapki', 'aapke', 'aapka', 'kya', 'kyun', 'hai', 'hain',
      'ho', 'mein', 'main', 'mujhe', 'tum', 'se', 'ko', 'ka', 'ki', 'ke', 'yeh', 'woh',
      'ham', 'hum', 'mera', 'meri', 'mere', 'apna', 'nahi', 'nahin', 'acha', 'achha',
      'theek', 'karo', 'karna', 'jana', 'jao', 'chahiye', 'bhi', 'par',
    };
    final words = text.toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.any(romanUrdu.contains)) return 'urdu';
    if (normalized == 'urdu' || normalized == 'roman urdu') return 'urdu';
    if (normalized == 'hindi' || normalized == 'hi') return 'hindi';
    return 'english';
  }

  List<String> _nativeLocaleCandidates(String deliveryLanguage) {
    switch (deliveryLanguage) {
      case 'urdu':
        return const ['ur-PK', 'ur-IN'];
      case 'hindi':
        return const ['hi-IN'];
      default:
        return const ['en-US', 'en-GB', 'en-IN'];
    }
  }

  Future<bool> _setNativeLocale(String deliveryLanguage) async {
    for (final locale in _nativeLocaleCandidates(deliveryLanguage)) {
      try {
        final available = await _native.isLanguageAvailable(locale);
        if (available == true || available.toString().toLowerCase() == 'true') {
          await _native.setLanguage(locale);
          return true;
        }
      } catch (_) {}
    }

    try {
      final voices = await _native.getVoices;
      if (voices is List) {
        final prefix = deliveryLanguage == 'urdu'
            ? 'ur'
            : deliveryLanguage == 'hindi'
                ? 'hi'
                : 'en';
        for (final raw in voices) {
          if (raw is! Map) continue;
          final locale = raw['locale']?.toString() ?? '';
          if (locale.toLowerCase().startsWith(prefix)) {
            await _native.setVoice(<String, String>{
              'name': raw['name']?.toString() ?? '',
              'locale': locale,
            });
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _speakNative(String text, String deliveryLanguage) async {
    final ready = await _setNativeLocale(deliveryLanguage);
    if (!ready) {
      throw StateError(
        'No installed ${deliveryLanguage[0].toUpperCase()}${deliveryLanguage.substring(1)} device voice is available',
      );
    }
    _speaking = true;
    try {
      await _native.speak(text);
      final deadline = DateTime.now().add(_nativeSpeechTimeout);
      while (_speaking && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (_speaking) {
        try { await _native.stop(); } catch (_) {}
        _speaking = false;
        throw TimeoutException('Native TTS did not complete within ${_nativeSpeechTimeout.inSeconds} seconds');
      }
    } finally {
      _speaking = false;
    }
  }

  Future<void> _speakCloud(String text, String deliveryLanguage) async {
    final key = '$deliveryLanguage|${text.trim()}';
    Uint8List? bytes = _cloudCache[key];
    if (bytes == null) {
      final result = await CloudTtsService.instance.synthesize(
        text: text,
        language: deliveryLanguage,
      );
      bytes = Uint8List.fromList(result.audioBytes);
      if (_cloudCache.length >= _maxCloudCacheEntries) {
        _cloudCache.remove(_cloudCache.keys.first);
      }
      _cloudCache[key] = bytes;
    }

    await _player.stop();
    _speaking = true;
    final completion = _player.onPlayerStateChanged.firstWhere(
      (state) => state == PlayerState.completed || state == PlayerState.stopped,
    );
    try {
      await _player.play(BytesSource(bytes));
      await completion.timeout(const Duration(seconds: 30));
    } finally {
      _speaking = false;
    }
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await initialize();

    final generation = ++_speakGeneration;
    final deliveryLanguage = _deliveryLanguage(language, value);
    await _stopPlaybackOnly();

    // Local Android/iOS TTS is intentionally first. Network TTS is used only
    // when the device lacks the requested language/voice, which removes the
    // common cloud round-trip from the normal English Speak-button path.
    try {
      await _speakNative(value, deliveryLanguage);
      if (generation != _speakGeneration) return;
      return;
    } catch (e) {
      if (generation != _speakGeneration) return;
      debugPrint('Native TTS unavailable; falling back to cloud TTS: $e');
    }

    if (generation != _speakGeneration) return;
    try {
      await _speakCloud(value, deliveryLanguage);
      if (generation != _speakGeneration) return;
    } catch (e) {
      if (generation != _speakGeneration) return;
      debugPrint('Cloud TTS unavailable: $e');
      rethrow;
    }
  }

  Future<void> _stopPlaybackOnly() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _native.stop();
    } catch (_) {}
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    ++_speakGeneration;
    await _stopPlaybackOnly();
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  void dispose() {
    ++_speakGeneration;
    _cloudCache.clear();
    unawaited(_player.dispose());
    unawaited(_native.stop());
  }
}

/// Speech provider with hybrid STT support and model management.
class SpeechProvider extends ChangeNotifier {
  late final EnhancedSpeechProvider _sttProvider;
  late final ResilientTtsProvider _ttsProvider;
  late final ModelManager _modelManager;

  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _lastSpokenText = '';
  String _latestFinalText = '';
  LanguageResult? _detectedLanguage;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';
  StreamSubscription<SpeechResultEvent>? _sttSubscription;
  StreamSubscription<ModelDownloadProgress>? _downloadSubscription;
  final Map<String, ModelDownloadProgress> _downloadProgress = {};
  bool _isDownloading = false;
  int _speechRunId = 0;

  SpeechProvider() {
    _sttProvider = EnhancedSpeechProvider();
    _ttsProvider = ResilientTtsProvider();
    _modelManager = ModelManager.instance;
  }

  EnhancedSpeechProvider get sttProvider => _sttProvider;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _sttProvider.isListening;
  String get lastSpokenText => _lastSpokenText;
  String get latestFinalText => _latestFinalText;
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
      case STTMode.sherpaStreaming: return 'Offline (Streaming)';
      case STTMode.sherpaBatch: return 'Offline (Batch)';
      case STTMode.platform: return 'Online';
      case STTMode.demo: return 'Demo Mode';
      case STTMode.none: return 'Unavailable';
    }
  }

  String get sttModeDescription {
    switch (_currentMode) {
      case STTMode.sherpaStreaming: return 'Real-time offline speech recognition using Sherpa-ONNX. No internet required.';
      case STTMode.sherpaBatch: return 'Offline speech recognition using Sherpa-ONNX. Short processing delay.';
      case STTMode.platform: return 'Online speech recognition using the configured streaming transcription service.';
      case STTMode.demo: return 'Demo mode with simulated captions. No actual speech recognition.';
      case STTMode.none: return 'Speech recognition unavailable. Please check microphone access or download a language model for offline use.';
    }
  }

  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_isInitialized) return;
    _currentLanguage = preferredLanguage;
    await _modelManager.initialize();
    _downloadSubscription = _modelManager.onProgress.listen((progress) {
      _downloadProgress[progress.language] = progress;
      _isDownloading = _downloadProgress.values.any((p) => p.status == DownloadStatus.downloading);
      notifyListeners();
    });
    await _sttProvider.initialize(preferredLanguage: preferredLanguage);
    await _ttsProvider.initialize();
    _currentMode = _sttProvider.currentMode;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> warmUpTts() async {
    await _ttsProvider.warmUp();
  }

  Future<void> startListening({String language = 'English'}) async {
    await _sttSubscription?.cancel();
    _sttSubscription = _sttProvider.onResult.listen((result) {
      _currentMode = result.mode;
      if (result.isFinal && result.text.trim().isNotEmpty) {
        _latestFinalText = result.text.trim();
        detectLanguage(result.text);
      }
      notifyListeners();
    });
    await _sttProvider.startListening(language: language);
    _currentMode = _sttProvider.currentMode;
    _currentLanguage = language;
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _sttProvider.stopListening();
    await _sttSubscription?.cancel();
    _sttSubscription = null;
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
  bool isModelReady(String language) => _modelManager.isModelReady(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];

  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) {
      if (_currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch) {
        await _sttProvider.switchLanguage(language);
        _currentMode = _sttProvider.currentMode;
      }
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success) {
      _currentMode = _sttProvider.currentMode;
      notifyListeners();
    }
    return success;
  }

  Stream<SpeechResultEvent> get onResult => _sttProvider.onResult;

  /// Returns the internal processing language for a transcript without changing
  /// the public detected-language result used by the UI.
  String processingLanguageForText(String text, {String fallback = 'English'}) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'Hindi';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'Urdu';
    const romanUrduWords = ['kya', 'hai', 'mein', 'tum', 'aap', 'ho', 'se', 'ko', 'ka', 'ki', 'ke'];
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (romanUrduWords.any(words.contains)) return 'Roman Urdu';
    return fallback;
  }

  Future<void> speak(String text, {String language = 'English'}) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final runId = ++_speechRunId;
    final wasListening = _sttProvider.isListening;
    final resumeLanguage = _currentLanguage;
    if (wasListening) {
      await _sttProvider.stopListening();
      await _sttSubscription?.cancel();
      _sttSubscription = null;
    }
    _isSpeaking = true;
    _lastSpokenText = value;
    notifyListeners();
    try {
      await _ttsProvider.speak(
        value,
        language: processingLanguageForText(value, fallback: language),
      );
    } finally {
      if (runId != _speechRunId) return;
      _isSpeaking = false;
      notifyListeners();
      if (wasListening) await startListening(language: resumeLanguage);
    }
  }

  Future<void> stopSpeaking() async {
    ++_speechRunId;
    await _ttsProvider.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  void detectLanguage(String text) {
    final urduScriptRegex = RegExp(r'[\u0600-\u06FF]');
    final romanUrduWords = ['kya', 'hai', 'mein', 'tum', 'aap', 'ho', 'se', 'ko', 'ka', 'ki', 'ke'];
    if (urduScriptRegex.hasMatch(text)) {
      _detectedLanguage = const LanguageResult(language: 'Urdu', confidence: 0.9, script: 'Arabic');
    } else if (romanUrduWords.any((w) => text.toLowerCase().split(RegExp(r'\s+')).contains(w))) {
      _detectedLanguage = const LanguageResult(language: 'Roman Urdu', confidence: 0.7, script: 'Latin');
    } else {
      _detectedLanguage = const LanguageResult(language: 'English', confidence: 0.85, script: 'Latin');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _speechRunId++;
    _sttSubscription?.cancel();
    _downloadSubscription?.cancel();
    _sttProvider.dispose();
    _ttsProvider.dispose();
    _modelManager.dispose();
    super.dispose();
  }
}
