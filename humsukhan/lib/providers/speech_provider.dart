import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/vosk_stt.dart';

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

class SpeechProvider extends ChangeNotifier {
  late final EnhancedSpeechProvider _sttProvider;
  late final TtsProvider _ttsProvider;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _lastSpokenText = '';
  LanguageResult? _detectedLanguage;
  STTMode _currentMode = STTMode.none;
  StreamSubscription<SpeechResultEvent>? _sttSubscription;

  SpeechProvider() {
    _sttProvider = EnhancedSpeechProvider();
    _ttsProvider = RealTtsProvider();
  }

  EnhancedSpeechProvider get sttProvider => _sttProvider;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;
  LanguageResult? get detectedLanguage => _detectedLanguage;
  STTMode get currentMode => _currentMode;

  bool get isOfflineMode => _currentMode == STTMode.sherpa;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;
  bool get isLiveStt => _currentMode != STTMode.none && _currentMode != STTMode.demo;

  String get sttModeLabel {
    switch (_currentMode) {
      case STTMode.sherpa:
        return 'Offline (Sherpa)';
      case STTMode.platform:
        return 'Online (Google)';
      case STTMode.demo:
        return 'Demo Mode';
      case STTMode.none:
        return 'Unavailable';
    }
  }

  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_isInitialized) return;
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
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _sttProvider.stopListening();
    _sttSubscription?.cancel();
    notifyListeners();
  }

  Future<void> switchToOfflineMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.sherpa, language: language);
    _currentMode = STTMode.sherpa;
    notifyListeners();
  }

  Future<void> switchToOnlineMode({String language = 'English'}) async {
    await _sttProvider.switchMode(STTMode.platform, language: language);
    _currentMode = STTMode.platform;
    notifyListeners();
  }

  List<String> get offlineLanguages => _sttProvider.offlineLanguages;

  Future<bool> downloadOfflineModel(String language) async {
    return await _sttProvider.downloadModel(language);
  }

  Stream<SpeechResultEvent> get onResult => _sttProvider.onResult;

  Future<void> speak(String text, {String language = 'English'}) async {
    _isSpeaking = true;
    _lastSpokenText = text;
    notifyListeners();
    await _ttsProvider.speak(text, language: language);
    _isSpeaking = false;
    notifyListeners();
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
    _sttProvider.dispose();
    _ttsProvider.dispose();
    super.dispose();
  }
}
