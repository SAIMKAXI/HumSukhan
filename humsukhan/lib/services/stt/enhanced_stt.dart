import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Enhanced Speech-to-Text using platform-native Google STT
/// On Android, this uses Google's on-device or cloud speech recognition.
/// Falls back to mock if speech_to_text is unavailable.
class EnhancedSpeechProvider {
  final SpeechToText _speech = SpeechToText();
  final StreamController<SpeechResultEvent> _controller =
      StreamController<SpeechResultEvent>.broadcast();

  bool _initialized = false;
  bool _listening = false;
  bool _available = false;

  static const _demoPhrases = [
    'Today we will discuss the project timeline and testing requirements.',
    'The deadline for the first phase is September 10th.',
    'We need to prepare the launch documentation by next week.',
    "Let's review the deployment checklist together.",
    'Can someone take notes for the action items?',
    'I will follow up on the testing results.',
    'Great, let\'s move to the next agenda item.',
    'The stakeholder review is scheduled for Friday.',
  ];

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _available;

  Future<bool> initialize() async {
    if (_initialized) return _available;
    try {
      _available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (error) {
          debugPrint('STT error: ${error.errorMsg}');
          if (error.errorMsg == 'no_match' || error.errorMsg == 'speech_timeout') {
            if (_listening) {
              _speech.listen();
            }
          }
        },
      );
      _initialized = true;
      debugPrint('STT initialized: available=$_available');
      return _available;
    } catch (e) {
      debugPrint('STT initialization failed: $e');
      _available = false;
      _initialized = true;
      return false;
    }
  }

  void _onStatus(String status) {
    debugPrint('STT status: $status');
    if (status == 'notListening' && _listening) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_listening) {
          _speech.listen();
        }
      });
    }
  }

  Future<void> startListening({
    String language = 'English',
    Duration listenFor = const Duration(minutes: 30),
    Duration pauseFor = const Duration(seconds: 5),
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (_available) {
      _listening = true;
      _speech.listen(
        onResult: _onSpeechResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: _getLocaleId(language),
        cancelOnError: false,
        partialResults: true,
      );
    } else {
      _listening = true;
      _startDemoMode();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _controller.add(SpeechResultEvent(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.confidence,
      language: _detectLanguage(result.recognizedWords),
      isLive: true,
    ));
  }

  Future<void> stopListening() async {
    _listening = false;
    if (_available) {
      await _speech.stop();
    }
    _demoTimer?.cancel();
  }

  Future<void> toggle({String language = 'English'}) async {
    if (_listening) {
      await stopListening();
    } else {
      await startListening(language: language);
    }
  }

  Timer? _demoTimer;

  void _startDemoMode() {
    var phraseIndex = 0;
    _demoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_listening || phraseIndex >= _demoPhrases.length) {
        timer.cancel();
        return;
      }
      final phrase = _demoPhrases[phraseIndex];
      _controller.add(SpeechResultEvent(
        text: phrase.substring(0, (phrase.length * 0.6).toInt()),
        isFinal: false,
        confidence: 0.7,
        language: 'English',
        isLive: false,
      ));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_listening) {
          _controller.add(SpeechResultEvent(
            text: phrase,
            isFinal: true,
            confidence: 0.92,
            language: 'English',
            isLive: false,
          ));
        }
      });
      phraseIndex++;
    });
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
    _demoTimer?.cancel();
    _speech.cancel();
    _controller.close();
  }
}

class SpeechResultEvent {
  final String text;
  final bool isFinal;
  final double confidence;
  final String language;
  final bool isLive;

  const SpeechResultEvent({
    required this.text,
    this.isFinal = false,
    this.confidence = 0.0,
    this.language = 'English',
    this.isLive = true,
  });
}
