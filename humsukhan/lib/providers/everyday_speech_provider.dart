import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/everyday_bilingual_stt.dart';
import '../services/everyday_language_policy.dart';
import '../services/roman_urdu_detector.dart';
import '../services/speech_engine.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';
import 'speech_provider.dart' show ResilientTtsProvider;

/// Everyday Mode speech provider.
///
/// Everyday owns one TTS implementation and one fallback STT controller. The
/// bilingual recognizer is only created for Auto mode; explicit English/Urdu
/// modes use a single language stream. This avoids the legacy provider's
/// hidden second TTS stack and prevents unused recognizers from being opened.
class EverydaySpeechProvider extends ChangeNotifier implements SpeechEngine {
  final EverydayBilingualSttService _bilingual = EverydayBilingualSttService.instance;
  final ResilientTtsProvider _ttsProvider = ResilientTtsProvider();
  final EnhancedSpeechProvider _fallbackStt = EnhancedSpeechProvider();
  final StreamController<SpeechResultEvent> _results = StreamController<SpeechResultEvent>.broadcast();
  final ModelManager _modelManager = ModelManager.instance;

  StreamSubscription<EverydayBilingualResult>? _bilingualSubscription;
  StreamSubscription<SpeechResultEvent>? _fallbackSubscription;
  bool _initialized = false;
  bool _listening = false;
  bool _usingFallback = false;
  bool _forceFallbackMode = false;
  bool _speaking = false;
  String _language = 'Auto';
  String _lastSpoken = '';
  String _latestFinal = '';
  String? _lastStartError;
  LanguageResult? _detected;
  STTMode _currentMode = STTMode.platform;
  int _speechGeneration = 0;

  bool get isInitialized => _initialized;
  bool get isListening => _listening;
  bool get isSpeaking => _speaking;
  String get currentLanguage => _language;
  String get lastSpokenText => _lastSpoken;
  String get latestFinalText => _latestFinal;
  String? get lastStartError => _lastStartError ?? _bilingual.lastStartError ?? _fallbackStt.lastStartError;
  LanguageResult? get detectedLanguage => _detected;
  STTMode get currentMode => _currentMode;
  bool get isAvailable => _initialized || _fallbackStt.isAvailable;
  bool get isPlatformAvailable => _fallbackStt.isPlatformAvailable;
  bool get isSherpaAvailable => _fallbackStt.isSherpaAvailable;
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => false;
  bool get isLiveStt => _listening;
  EnhancedSpeechProvider get sttProvider => _fallbackStt;
  Stream<SpeechResultEvent> get onResult => _results.stream;

  String get sttModeLabel {
    switch (_currentMode) {
      case STTMode.sherpaStreaming:
        return 'Offline (Streaming)';
      case STTMode.sherpaBatch:
        return 'Offline (Batch)';
      case STTMode.platform:
        return _usingFallback ? 'Platform fallback' : 'Online';
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
        return 'Online speech recognition using the configured streaming transcription service.';
      case STTMode.demo:
        return 'Demo mode with simulated captions. No actual speech recognition.';
      case STTMode.none:
        return 'Speech recognition unavailable. Please check microphone access or download a language model for offline use.';
    }
  }

  Future<void> initialize({String preferredLanguage = 'Auto'}) async {
    if (_initialized) return;
    _language = _normalizeLanguage(preferredLanguage);
    await _modelManager.initialize();
    await _fallbackStt.initialize(preferredLanguage: preferredLanguage);
    await _ttsProvider.initialize();
    _initialized = true;
    _currentMode = _fallbackStt.currentMode;
    notifyListeners();
  }

  Future<bool> warmUpTts() => _ttsProvider.warmUp();

  Future<void> startListening({String language = 'Auto'}) async {
    await _bilingualSubscription?.cancel();
    await _fallbackSubscription?.cancel();
    _bilingualSubscription = null;
    _fallbackSubscription = null;
    _lastStartError = null;
    _language = _normalizeLanguage(language);
    _listening = false;
    _usingFallback = false;

    if (_language == 'Auto' && !_forceFallbackMode) {
      final started = await _bilingual.start();
      if (started) {
        _currentMode = STTMode.platform;
        _listening = true;
        _bilingualSubscription = _bilingual.onResult.listen((result) {
          final text = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
          if (text.isEmpty) return;
          final detected = _detectCaptionLanguage(text, fallback: 'English');
          _currentMode = result.mode;
          if (result.isFinal) _latestFinal = text;
          _updateDetection(text, detected);
          _results.add(SpeechResultEvent(
            text: text,
            isFinal: result.isFinal,
            mode: result.mode,
          ));
          notifyListeners();
        });
        notifyListeners();
        return;
      }
      _lastStartError = _bilingual.lastStartError;
    }

    _usingFallback = true;
    _fallbackSubscription = _fallbackStt.onResult.listen((result) {
      _currentMode = result.mode;
      if (result.isFinal && result.text.trim().isNotEmpty) {
        _latestFinal = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
        _updateDetection(result.text, _language == 'Auto' ? 'English' : _language);
      }
      _results.add(result);
      notifyListeners();
    });
    try {
      await _fallbackStt.startListening(language: _language == 'Auto' ? 'English' : _language);
      _currentMode = _fallbackStt.currentMode;
      _listening = _fallbackStt.isListening;
    } catch (e) {
      _lastStartError = e.toString();
      _listening = false;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _bilingual.stop();
    await _fallbackStt.stopListening();
    await _bilingualSubscription?.cancel();
    await _fallbackSubscription?.cancel();
    _bilingualSubscription = null;
    _fallbackSubscription = null;
    _listening = false;
    notifyListeners();
  }

  Future<void> switchMode(STTMode mode, {String language = 'English'}) async {
    _forceFallbackMode = mode != STTMode.platform;
    await stopListening();
    _language = _normalizeLanguage(language);
    await _fallbackStt.switchMode(mode, language: _language == 'Auto' ? 'English' : _language);
    _currentMode = _fallbackStt.currentMode;
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    final normalized = _normalizeLanguage(language);
    _language = normalized;
    await _fallbackStt.switchLanguage(normalized == 'Auto' ? 'English' : normalized);
    _currentMode = _fallbackStt.currentMode;
    notifyListeners();
  }

  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();
  List<String> get readyLanguages => _modelManager.readyLanguages;
  bool isModelReady(String language) => _modelManager.isModelReady(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];

  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success && isOfflineMode) {
      await switchLanguage(language);
    }
    notifyListeners();
    return success;
  }

  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success) {
      _currentMode = _fallbackStt.currentMode;
      notifyListeners();
    }
    return success;
  }

  String processingLanguageForText(String text, {String fallback = 'English'}) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (safe.isEmpty) return fallback == 'Auto' ? 'English' : fallback;
    if (EverydayLanguagePolicy.containsUrduScript(safe)) return 'Urdu';
    if (RomanUrduDetector.isRomanUrdu(safe)) return 'Roman Urdu';
    return fallback == 'Auto' ? 'English' : fallback;
  }

  Future<void> speak(String text, {String language = 'English'}) async {
    final value = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (value.isEmpty) return;
    final runId = ++_speechGeneration;
    final wasListening = _listening;
    final resumeLanguage = _language;
    if (wasListening) {
      await stopListening();
    }
    _speaking = true;
    _lastSpoken = value;
    notifyListeners();
    try {
      await _ttsProvider.speak(
        value,
        language: processingLanguageForText(value, fallback: language),
      );
    } finally {
      if (runId != _speechGeneration) return;
      _speaking = false;
      notifyListeners();
      if (wasListening) await startListening(language: resumeLanguage);
    }
  }

  Future<void> stopSpeaking() async {
    ++_speechGeneration;
    await _ttsProvider.stop();
    _speaking = false;
    notifyListeners();
  }

  void _updateDetection(String text, String fallback) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (safe.isEmpty) {
      _detected = null;
      return;
    }
    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(safe);
    final language = hasUrdu ? 'Urdu' : RomanUrduDetector.isRomanUrdu(safe) ? 'Roman Urdu' : fallback;
    _detected = LanguageResult(
      language: language,
      confidence: hasUrdu || language != 'English' ? .92 : .85,
      script: hasUrdu ? 'Arabic' : 'Latin',
    );
  }

  String _detectCaptionLanguage(String text, {required String fallback}) {
    if (EverydayLanguagePolicy.containsUrduScript(text)) return 'Urdu';
    if (RomanUrduDetector.isRomanUrdu(text)) return 'Roman Urdu';
    return fallback == 'Auto' ? 'English' : fallback;
  }

  String _normalizeLanguage(String language) {
    final value = language.trim().toLowerCase();
    if (value == 'urdu') return 'Urdu';
    if (value == 'roman urdu' || value == 'roman_urdu') return 'Roman Urdu';
    if (value == 'auto') return 'Auto';
    return 'English';
  }

  @override
  void dispose() {
    ++_speechGeneration;
    _bilingualSubscription?.cancel();
    _fallbackSubscription?.cancel();
    _results.close();
    _bilingual.stop();
    _fallbackStt.stopListening();
    _ttsProvider.dispose();
    _fallbackStt.dispose();
    _modelManager.dispose();
    super.dispose();
  }
}

typedef SpeechProvider = EverydaySpeechProvider;
