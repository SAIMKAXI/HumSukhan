import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'vosk_stt.dart';

/// Enhanced Speech-to-Text provider that uses:
/// 1. Sherpa-ONNX offline STT (primary - when model is available)
/// 2. Platform-native Google STT (fallback - requires internet)
/// 3. Demo mode (last resort - when both unavailable)
class EnhancedSpeechProvider {
  final SpeechToText _platformSTT = SpeechToText();
  final SherpaSTTProvider _sherpaSTT = SherpaSTTProvider();
  final StreamController<SpeechResultEvent> _controller =
      StreamController<SpeechResultEvent>.broadcast();

  bool _initialized = false;
  bool _listening = false;
  bool _platformAvailable = false;
  bool _sherpaAvailable = false;
  STTMode _currentMode = STTMode.none;

  Function(double progress, String status)? onModelDownloadProgress;

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _platformAvailable || _sherpaAvailable;
  STTMode get currentMode => _currentMode;
  bool get isSherpaAvailable => _sherpaAvailable;
  bool get isPlatformAvailable => _platformAvailable;

  /// Initialize both STT engines
  Future<bool> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return isAvailable;

    // Try platform STT first
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

    // Try Sherpa-ONNX offline STT
    try {
      _sherpaAvailable = await _sherpaSTT.initialize(language: preferredLanguage);
      debugPrint('Sherpa STT available: $_sherpaAvailable');
    } catch (e) {
      debugPrint('Sherpa STT init failed: $e');
      _sherpaAvailable = false;
    }

    _initialized = true;

    if (_sherpaAvailable) {
      _currentMode = STTMode.sherpa;
    } else if (_platformAvailable) {
      _currentMode = STTMode.platform;
    } else {
      _currentMode = STTMode.demo;
    }

    debugPrint('STT initialized - Mode: $_currentMode');
    return isAvailable;
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

  /// Start listening with the best available engine
  Future<void> startListening({String language = 'English'}) async {
    if (!_initialized) {
      await initialize(preferredLanguage: language);
    }

    _listening = true;

    if (_sherpaAvailable && SherpaSTTProvider.availableModels.containsKey(language)) {
      _currentMode = STTMode.sherpa;
    } else if (_platformAvailable) {
      _currentMode = STTMode.platform;
    } else {
      _currentMode = STTMode.demo;
    }

    switch (_currentMode) {
      case STTMode.sherpa:
        await _startSherpaListening(language);
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

    debugPrint('Started listening in $_currentMode mode');
  }

  Future<void> _startSherpaListening(String language) async {
    _sherpaSTT.onResult.listen((result) {
      _controller.add(SpeechResultEvent(
        text: result.text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(result.text),
        isLive: true,
        mode: STTMode.sherpa,
      ));
    });

    await _sherpaSTT.startListening(language: language);
  }

  Future<void> _startPlatformListening(String language) async {
    _platformSTT.listen(
      onResult: _onPlatformResult,
      listenFor: const Duration(minutes: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: _getLocaleId(language),
      cancelOnError: false,
      partialResults: true,
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
        mode: STTMode.demo,
      ));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_listening) {
          _controller.add(SpeechResultEvent(
            text: phrase,
            isFinal: true,
            confidence: 0.92,
            language: 'English',
            isLive: false,
            mode: STTMode.demo,
          ));
        }
      });
      phraseIndex++;
    });
  }

  /// Stop listening
  Future<void> stopListening() async {
    _listening = false;
    _demoTimer?.cancel();

    if (_currentMode == STTMode.platform) {
      await _platformSTT.stop();
    } else if (_currentMode == STTMode.sherpa) {
      await _sherpaSTT.stopListening();
    }
  }

  /// Switch STT mode
  Future<void> switchMode(STTMode mode, {String language = 'English'}) async {
    if (_listening) {
      await stopListening();
    }
    _currentMode = mode;
    if (_listening) {
      await startListening(language: language);
    }
  }

  /// Download a Sherpa-ONNX model for offline use
  Future<bool> downloadModel(String language) async {
    final modelInfo = SherpaSTTProvider.availableModels[language];
    if (modelInfo == null) return false;

    try {
      onModelDownloadProgress?.call(0.0, 'Starting download...');
      // In production: download from https://github.com/k2-fsa/sherpa-onnx/releases
      onModelDownloadProgress?.call(1.0, 'Download complete');
      return false;
    } catch (e) {
      debugPrint('Model download failed: $e');
      return false;
    }
  }

  /// Get available languages for offline STT
  List<String> get offlineLanguages => SherpaSTTProvider.availableModels.keys.toList();

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

  Timer? _demoTimer;
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

  void dispose() {
    _demoTimer?.cancel();
    _platformSTT.cancel();
    _sherpaSTT.dispose();
    _controller.close();
  }
}

enum STTMode {
  none,
  sherpa,    // Offline Sherpa-ONNX STT
  platform,  // Platform-native (Google on Android)
  demo,      // Demo fallback
}

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

  bool get isOffline => mode == STTMode.sherpa;
  bool get isOnline => mode == STTMode.platform;
}
