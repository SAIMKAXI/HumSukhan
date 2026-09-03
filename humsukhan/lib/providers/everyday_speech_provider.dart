import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/everyday_bilingual_stt.dart';
import '../services/everyday_language_policy.dart';
import '../services/roman_urdu_detector.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';
import 'speech_provider.dart' show ResilientTtsProvider;

/// Everyday Mode speech provider.
///
/// Everyday owns one TTS implementation and one fallback STT controller. The
/// bilingual recognizer is only created for Auto mode; explicit English/Urdu
/// modes use a single language stream. This avoids the legacy provider's
/// hidden second TTS stack and prevents unused recognizers from being opened.
class EverydaySpeechProvider extends ChangeNotifier {
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
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _listening && !isOfflineMode;
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
      await _ttsProvider.initialize();
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

    // Everyday has a real degraded path: native platform STT first through
    // the existing EnhancedSpeechProvider, then its configured Sherpa model.
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
    if (wasListening) await startListening(language: _language);
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    final wasListening = _listening;
    await stopListening();
    _language = _normalizeLanguage(language);
    if (_forceFallbackMode) {
      await _fallbackStt.switchLanguage(_language == 'Auto' ? 'English' : _language);
      _currentMode = _fallbackStt.currentMode;
    } else {
      _currentMode = STTMode.platform;
    }
    if (wasListening) await startListening(language: _language);
    notifyListeners();
  }

  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();
  List<String> get readyLanguages => _modelManager.readyLanguages;
  bool isModelReady(String language) => _modelManager.isModelReady(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];

  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success && _forceFallbackMode) {
      await _fallbackStt.switchLanguage(language);
      _currentMode = _fallbackStt.currentMode;
    }
    notifyListeners();
    return success;
  }

  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success && _forceFallbackMode) _currentMode = _fallbackStt.currentMode;
    notifyListeners();
    return success;
  }

  String processingLanguageForText(String text, {String fallback = 'English'}) {
    final safe = EverydayLanguagePolicy.normalizeRomanUrdu(text).trim();
    if (safe.isEmpty) return fallback == 'Auto' ? 'English' : fallback;
    if (EverydayLanguagePolicy.containsUrduScript(safe)) return 'Urdu';
    if (RomanUrduDetector.isRomanUrdu(safe)) return 'Roman Urdu';
    return fallback == 'Auto' ? 'English' : fallback;
  }

  Future<void> speak(String text, {String language = 'English'}) async {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (safe.isEmpty) return;
    await initialize(preferredLanguage: language);
    final generation = ++_speechGeneration;
    final wasListening = _listening;
    final resumeLanguage = _language;
    if (wasListening) await stopListening();

    _lastSpoken = safe;
    _speaking = true;
    notifyListeners();
    try {
      final requested = _normalizeLanguage(language);
      if (requested == 'English') {
        await _speakEnglishMode(safe, generation);
      } else {
        final normalized = EverydayLanguagePolicy.normalizeRomanUrdu(safe);
        for (final segment in _splitForSpeech(normalized)) {
          if (generation != _speechGeneration) return;
          await _ttsProvider.speak(segment.text, language: segment.language);
        }
      }
    } finally {
      if (generation != _speechGeneration) return;
      _speaking = false;
      notifyListeners();
      if (wasListening) await startListening(language: resumeLanguage);
    }
  }

  Future<void> _speakEnglishMode(String text, int generation) async {
    final converted = EverydayLanguagePolicy.toEnglishMode(text);
    for (final segment in _splitForSpeech(converted)) {
      if (generation != _speechGeneration) return;
      await _ttsProvider.speak(segment.text, language: segment.language);
    }
  }

  List<_SpeechSegment> _splitForSpeech(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    final result = <_SpeechSegment>[];
    var current = 'english';
    final buffer = <String>[];

    void flush() {
      if (buffer.isNotEmpty) {
        result.add(_SpeechSegment(buffer.join(' '), current));
        buffer.clear();
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.isEmpty) continue;
      final isUrdu = EverydayLanguagePolicy.containsUrduScript(token);
      final pair = i + 1 < tokens.length ? '$token ${tokens[i + 1]}' : token;
      final isRoman = RomanUrduDetector.isRomanUrdu(pair);

      if (isUrdu || isRoman) {
        if (current != 'urdu') flush();
        current = 'urdu';
        buffer.add(token);
        continue;
      }

      if (current == 'urdu') {
        final previous = buffer.isEmpty ? token : '${buffer.last} $token';
        if (RomanUrduDetector.isRomanUrdu(previous)) {
          buffer.add(token);
          continue;
        }
        flush();
        current = 'english';
      }
      buffer.add(token);
    }
    flush();
    return result;
  }

  Future<void> stopSpeaking() async {
    ++_speechGeneration;
    await _ttsProvider.stop();
    _speaking = false;
    notifyListeners();
  }

  void detectLanguage(String text) {
    final safe = EverydayLanguagePolicy.normalizeRomanUrdu(text).trim();
    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(safe);
    final hasEnglish = EverydayLanguagePolicy.containsLatin(safe);
    final hasRomanUrdu = !hasUrdu && RomanUrduDetector.isRomanUrdu(safe);
    final language = hasUrdu && hasEnglish
        ? 'Auto'
        : hasUrdu
            ? 'Urdu'
            : hasRomanUrdu
                ? 'Roman Urdu'
                : 'English';
    _detected = LanguageResult(
      language: language,
      confidence: hasUrdu && hasEnglish ? 0.85 : hasRomanUrdu ? 0.92 : 0.9,
      script: hasUrdu && hasEnglish ? 'Mixed' : hasUrdu ? 'Arabic' : 'Latin',
    );
    notifyListeners();
  }

  String _detectCaptionLanguage(String text, {required String fallback}) {
    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(text);
    if (hasUrdu && EverydayLanguagePolicy.containsLatin(text)) return 'Auto';
    if (hasUrdu) return 'Urdu';
    if (RomanUrduDetector.isRomanUrdu(text)) return 'Roman Urdu';
    return fallback == 'Auto' ? 'English' : fallback;
  }

  String _normalizeLanguage(String language) {
    switch (language.toLowerCase().trim()) {
      case 'english':
      case 'en':
        return 'English';
      case 'urdu':
      case 'ur':
      case 'roman urdu':
        return 'Urdu';
      default:
        return 'Auto';
    }
  }

  @override
  void dispose() {
    _speechGeneration++;
    unawaited(_bilingualSubscription?.cancel());
    unawaited(_fallbackSubscription?.cancel());
    unawaited(_bilingual.stop());
    unawaited(_fallbackStt.stopListening());
    _ttsProvider.dispose();
    _results.close();
    super.dispose();
  }
}

final class _SpeechSegment {
  const _SpeechSegment(this.text, this.language);
  final String text;
  final String language;
}

class SpeechProvider extends EverydaySpeechProvider {}
