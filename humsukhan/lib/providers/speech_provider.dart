import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

// ===================== PROVIDER INTERFACES =====================
abstract class SpeechToTextProvider {
  Future<bool> initialize();
  Future<void> startListening({String language = 'English'});
  Future<void> stopListening();
  Stream<SpeechResult> get onResult;
  bool get isListening;
  bool get isAvailable;
  void dispose();
}

abstract class TtsProvider {
  Future<bool> initialize();
  Future<void> speak(String text, {String language = 'English'});
  Future<void> stop();
  bool get isSpeaking;
  void dispose();
}

class SpeechResult {
  final String text;
  final bool isFinal;
  final double confidence;
  final String language;

  const SpeechResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
    this.language = 'English',
  });
}

// ===================== MOCK SPEECH PROVIDER =====================
class MockSpeechProvider implements SpeechToTextProvider {
  final _controller = StreamController<SpeechResult>.broadcast();
  bool _listening = false;
  bool _available = true;
  Timer? _demoTimer;

  static const _demoPhrases = [
    'Today we will discuss the project timeline.',
    'The testing phase begins next week.',
    'We need to prepare the documentation.',
    'Let\'s review the deployment checklist.',
    'The deadline is September 15th.',
    'Can someone take notes for this meeting?',
    'I will follow up on the action items.',
    'Great, let\'s move to the next agenda item.',
  ];

  @override
  Future<bool> initialize() async {
    _available = true;
    return true;
  }

  @override
  Future<void> startListening({String language = 'English'}) async {
    _listening = true;
    _startDemoStream();
  }

  void _startDemoStream() {
    var phraseIndex = 0;
    _demoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_listening || phraseIndex >= _demoPhrases.length) {
        timer.cancel();
        return;
      }
      final phrase = _demoPhrases[phraseIndex];

      // Partial result
      _controller.add(SpeechResult(
        text: phrase.substring(0, (phrase.length * 0.6).toInt()),
        isFinal: false,
        confidence: 0.7,
        language: 'English',
      ));

      // Final result after brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_listening) {
          _controller.add(SpeechResult(
            text: phrase,
            isFinal: true,
            confidence: 0.92,
            language: 'English',
          ));
        }
      });

      phraseIndex++;
    });
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
    _demoTimer?.cancel();
  }

  @override
  Stream<SpeechResult> get onResult => _controller.stream;

  @override
  bool get isListening => _listening;

  @override
  bool get isAvailable => _available;

  @override
  void dispose() {
    _demoTimer?.cancel();
    _controller.close();
  }
}

// ===================== MOCK TTS PROVIDER =====================
class MockTtsProvider implements TtsProvider {
  bool _speaking = false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    _speaking = true;
    // Simulate speaking duration
    await Future.delayed(Duration(seconds: (text.length / 20).ceil()));
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    _speaking = false;
  }

  @override
  bool get isSpeaking => _speaking;

  @override
  void dispose() {}
}

// ===================== SPEECH PROVIDER (MAIN) =====================
class SpeechProvider extends ChangeNotifier {
  late SpeechToTextProvider _sttProvider;
  late TtsProvider _ttsProvider;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _lastSpokenText = '';
  LanguageResult? _detectedLanguage;

  SpeechProvider() {
    _sttProvider = MockSpeechProvider();
    _ttsProvider = MockTtsProvider();
  }

  SpeechToTextProvider get sttProvider => _sttProvider;
  TtsProvider get ttsProvider => _ttsProvider;
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  String get lastSpokenText => _lastSpokenText;
  LanguageResult? get detectedLanguage => _detectedLanguage;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _sttProvider.initialize();
    await _ttsProvider.initialize();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> startListening({String language = 'English'}) async {
    await _sttProvider.startListening(language: language);
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _sttProvider.stopListening();
    notifyListeners();
  }

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

  Stream<SpeechResult> get onResult => _sttProvider.onResult;

  void detectLanguage(String text) {
    // Simple language detection heuristic
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
    _sttProvider.dispose();
    _ttsProvider.dispose();
    super.dispose();
  }
}
