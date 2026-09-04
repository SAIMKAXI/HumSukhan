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
        return _usingFallback
            ? 'Using the device speech recognizer after the primary Everyday recognizer became unavailable.'
            : 'Online bilingual speech recognition.';
      case STTMode.demo:
        return 'Demo mode with simulated captions.';
      case STTMode.none:
        return 'Speech recognition unavailable.';
    }
  }

  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return;
    _language = _normalizeLanguage(preferredLanguage);
    try {
      // Warm up once so any native-language capability calibration is completed
      // before the user's first Speak action. ResilientTtsProvider serializes
      // its probe with all later native TTS operations.
      await _ttsProvider.warmUp();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _lastStartError = 'Speech services could not initialize: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> warmUpTts() => _ttsProvider.warmUp();

  Future<void> startListening({String language = 'English'}) async {
    await initialize(preferredLanguage: language);
    if (_listening) return;

    _language = _normalizeLanguage(language);
    _lastStartError = null;
    _latestFinal = '';
    _detected = null;
    _currentMode = STTMode.platform;
    _usingFallback = false;

    if (_forceFallbackMode) {
      await _startFallback(_language == 'Auto' ? 'English' : _language);
      return;
    }

    await _bilingualSubscription?.cancel();
    _bilingualSubscription = _bilingual.onResult.listen(_handleResult);
    final started = await _bilingual.start(mode: _language);
    if (started) {
      _listening = true;
      notifyListeners();
      return;
    }

    await _bilingualSubscription?.cancel();
    _bilingualSubscription = null;
    await _startFallback(_language == 'Auto' ? 'English' : _language);
  }

  Future<void> _startFallback(String language) async {
    await _fallbackSubscription?.cancel();
    _fallbackSubscription = _fallbackStt.onResult.listen((result) {
      if (!_listening && result.isFinal == false) return;
      final safe = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
      if (safe.isEmpty || _results.isClosed) return;
      final normalized = EverydayLanguagePolicy.normalizeRomanUrdu(safe);
      final detected = _detectCaptionLanguage(normalized, fallback: language);
      if (result.isFinal) _latestFinal = normalized;
      _detected = LanguageResult(
        language: detected,
        confidence: result.confidence,
        script: EverydayLanguagePolicy.containsUrduScript(normalized) ? 'Arabic' : 'Latin',
      );
      _results.add(SpeechResultEvent(
        text: normalized,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: detected,
        isLive: true,
        mode: result.mode,
      ));
      _currentMode = result.mode;
      notifyListeners();
    });

    try {
      await _fallbackStt.startListening(language: language);
      if (_fallbackStt.isListening) {
        _listening = true;
        _usingFallback = true;
        _currentMode = _fallbackStt.currentMode;
        notifyListeners();
        return;
      }
    } catch (e) {
      _lastStartError = 'Fallback speech recognition could not start: $e';
    }

    _listening = false;
    _usingFallback = false;
    _currentMode = STTMode.none;
    _lastStartError ??= _fallbackStt.lastStartError ?? 'Live speech recognition could not be started.';
    await _fallbackSubscription?.cancel();
    _fallbackSubscription = null;
    notifyListeners();
  }

  void _handleResult(EverydayBilingualResult result) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
    if (safe.isEmpty) return;

    final normalized = _language == 'English'
        ? EverydayLanguagePolicy.toEnglishMode(safe)
        : EverydayLanguagePolicy.normalizeRomanUrdu(safe);
    if (normalized.trim().isEmpty) return;

    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(normalized);
    final hasEnglish = EverydayLanguagePolicy.containsLatin(normalized);
    final hasRomanUrdu = !hasUrdu && RomanUrduDetector.isRomanUrdu(normalized);
    final language = hasUrdu && hasEnglish
        ? 'Auto'
        : hasUrdu
            ? 'Urdu'
            : hasRomanUrdu
                ? 'Roman Urdu'
                : 'English';
    _detected = LanguageResult(
      language: language,
      confidence: result.confidence,
      script: hasUrdu && hasEnglish ? 'Mixed' : hasUrdu ? 'Arabic' : 'Latin',
    );
    if (result.isFinal) _latestFinal = normalized;
    if (!_results.isClosed) {
      _results.add(SpeechResultEvent(
        text: normalized,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: language,
        isLive: true,
        mode: STTMode.platform,
      ));
    }
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    await _bilingual.stop();
    await _fallbackStt.stopListening();
    _listening = false;
    _usingFallback = false;
    await _bilingualSubscription?.cancel();
    await _fallbackSubscription?.cancel();
    _bilingualSubscription = null;
    _fallbackSubscription = null;
    notifyListeners();
  }

  Future<void> switchToOfflineStreamingMode({String language = 'English'}) async {
    await stopListening();
    _forceFallbackMode = true;
    await _fallbackStt.switchMode(STTMode.sherpaStreaming, language: language);
    _currentMode = STTMode.sherpaStreaming;
    _language = _normalizeLanguage(language);
    notifyListeners();
  }

  Future<void> switchToOfflineBatchMode({String language = 'Urdu'}) async {
    await stopListening();
    _forceFallbackMode = true;
    await _fallbackStt.switchMode(STTMode.sherpaBatch, language: language);
    _currentMode = STTMode.sherpaBatch;
    _language = _normalizeLanguage(language);
    notifyListeners();
  }

  Future<void> switchToOnlineMode({String language = 'English'}) async {
    final wasListening = _listening;
    await stopListening();
    _forceFallbackMode = false;
    _language = _normalizeLanguage(language);
    _currentMode = STTMode.platform;
    if (wasListening) await startListening(language: language);
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    final normalized = _normalizeLanguage(language);
    final wasListening = _listening;
    await stopListening();
    _language = normalized;
    if (_forceFallbackMode) {
      try {
        await _fallbackStt.switchLanguage(normalized == 'Auto' ? 'English' : normalized);
        _currentMode = _fallbackStt.currentMode;
      } catch (e) {
        _lastStartError = 'Could not switch speech language: $e';
      }
    }
    if (wasListening) await startListening(language: normalized);
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
        await _fallbackStt.switchLanguage(language);
        _currentMode = _fallbackStt.currentMode;
      }
      notifyListeners();
    }
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
    await initialize(preferredLanguage: language);
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
