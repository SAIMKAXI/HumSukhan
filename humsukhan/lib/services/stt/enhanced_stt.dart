import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'vosk_stt.dart';
import 'model_manager.dart';

export 'vosk_stt.dart' show STTMode;

class EnhancedSpeechProvider {
  final SpeechToText _platformSTT = SpeechToText();
  final SherpaSTTProvider _sherpaSTT = SherpaSTTProvider();
  final StreamController<SpeechResultEvent> _controller =
      StreamController<SpeechResultEvent>.broadcast();
  final ModelManager _modelManager = ModelManager.instance;

  bool _initialized = false;
  bool _listening = false;
  bool _platformAvailable = false;
  bool _sherpaAvailable = false;
  bool _platformRestartInFlight = false;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';
  String _platformLocale = 'en-US';
  StreamSubscription<SherpaSTTResult>? _sherpaSubscription;
  Timer? _platformRestartTimer;

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _platformAvailable || _sherpaAvailable;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;
  bool get isSherpaAvailable => _sherpaAvailable;
  bool get isPlatformAvailable => _platformAvailable;

  bool get isOfflineMode =>
      _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;

  Future<bool> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return isAvailable;

    _currentLanguage = preferredLanguage;
    await _modelManager.initialize();

    try {
      _sherpaAvailable = await _sherpaSTT.initialize(language: preferredLanguage);
    } catch (e) {
      debugPrint('Sherpa STT init failed: $e');
      _sherpaAvailable = false;
    }

    try {
      _platformAvailable = await _platformSTT.initialize(
        onStatus: _onPlatformStatus,
        onError: (error) {
          debugPrint('Platform STT error: ${error.errorMsg}');
          if (_listening && _currentMode == STTMode.platform) {
            _schedulePlatformRestart(delay: const Duration(milliseconds: 500));
          }
        },
      );
    } catch (e) {
      debugPrint('Platform STT init failed: $e');
      _platformAvailable = false;
    }

    _initialized = true;
    _updateModeForLanguage(preferredLanguage);
    return isAvailable;
  }

  void _updateModeForLanguage(String language) {
    if (_sherpaAvailable && _modelManager.isModelReady(language)) {
      final model = _modelManager.getBestModel(language);
      _currentMode = model?.isStreaming == true
          ? STTMode.sherpaStreaming
          : STTMode.sherpaBatch;
    } else if (_platformAvailable) {
      _currentMode = STTMode.platform;
    } else {
      _currentMode = STTMode.none;
    }
  }

  void _onPlatformStatus(String status) {
    if (!_listening || _currentMode != STTMode.platform) return;
    // Android's platform recognizer can terminate a recognition window even
    // while the app is still in an active conversation/session. Keep the app's
    // listening state alive and restart the recognizer without touching the
    // accumulated transcript.
    if (status == 'notListening' || status == 'done') {
      _schedulePlatformRestart(delay: const Duration(milliseconds: 350));
    }
  }

  void _schedulePlatformRestart({Duration delay = const Duration(milliseconds: 350)}) {
    if (!_listening || _currentMode != STTMode.platform) return;
    if (_platformRestartTimer?.isActive == true || _platformRestartInFlight) return;

    _platformRestartTimer = Timer(delay, () async {
      if (!_listening || _currentMode != STTMode.platform || _platformRestartInFlight) return;
      _platformRestartInFlight = true;
      try {
        await _platformSTT.listen(
          onResult: _onPlatformResult,
          listenOptions: SpeechListenOptions(
            listenFor: const Duration(minutes: 30),
            pauseFor: const Duration(seconds: 30),
            localeId: _platformLocale,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      } catch (e) {
        debugPrint('Platform STT restart failed: $e');
        if (_listening && _currentMode == STTMode.platform) {
          _platformRestartTimer = Timer(const Duration(seconds: 1), () {
            _platformRestartTimer = null;
            _schedulePlatformRestart(delay: Duration.zero);
          });
          return;
        }
      } finally {
        _platformRestartInFlight = false;
      }
    });
  }

  Future<void> startListening({String language = 'English'}) async {
    if (!_initialized) await initialize(preferredLanguage: language);

    if (_listening) {
      if (language == _currentLanguage) return;
      await stopListening();
    }

    _currentLanguage = language;
    _updateModeForLanguage(language);
    _listening = true;

    try {
      switch (_currentMode) {
        case STTMode.sherpaStreaming:
          await _startSherpaStreaming(language);
          break;
        case STTMode.sherpaBatch:
          await _startSherpaBatch(language);
          break;
        case STTMode.platform:
          await _startPlatformListening(language);
          break;
        case STTMode.none:
        case STTMode.demo:
          _listening = false;
          debugPrint('Speech recognition unavailable for $language');
          break;
      }
    } catch (e) {
      _listening = false;
      debugPrint('Failed to start listening: $e');
    }
  }

  Future<void> _startSherpaStreaming(String language) async {
    _sherpaSubscription?.cancel();
    _sherpaSubscription = _sherpaSTT.onResult.listen((result) {
      _controller.add(SpeechResultEvent(
        text: result.text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(result.text, fallback: language),
        isLive: true,
        mode: STTMode.sherpaStreaming,
      ));
    });
    await _sherpaSTT.startListening(language: language);
  }

  Future<void> _startSherpaBatch(String language) async {
    _sherpaSubscription?.cancel();
    _sherpaSubscription = _sherpaSTT.onResult.listen((result) {
      _controller.add(SpeechResultEvent(
        text: result.text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(result.text, fallback: language),
        isLive: true,
        mode: STTMode.sherpaBatch,
      ));
    });
    await _sherpaSTT.startListening(language: language);
  }

  Future<void> _startPlatformListening(String language) async {
    _platformLocale = _getLocaleId(language);
    await _platformSTT.listen(
      onResult: _onPlatformResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
        localeId: _platformLocale,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _onPlatformResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords;
    _controller.add(SpeechResultEvent(
      text: text,
      isFinal: result.finalResult,
      confidence: result.confidence,
      language: _detectLanguage(text, fallback: _currentLanguage),
      isLive: true,
      mode: STTMode.platform,
    ));
  }

  Future<void> stopListening() async {
    _listening = false;
    _platformRestartTimer?.cancel();
    _platformRestartTimer = null;
    _platformRestartInFlight = false;
    _sherpaSubscription?.cancel();
    _sherpaSubscription = null;

    if (_currentMode == STTMode.platform) {
      await _platformSTT.stop();
    } else if (_currentMode == STTMode.sherpaStreaming ||
        _currentMode == STTMode.sherpaBatch) {
      await _sherpaSTT.stopListening();
    }
  }

  Future<void> switchMode(STTMode mode, {String language = 'English'}) async {
    final wasListening = _listening;
    if (wasListening) await stopListening();
    _currentMode = mode;
    _currentLanguage = language;
    if (wasListening) await startListening(language: language);
  }

  Future<void> switchLanguage(String language) async {
    final wasListening = _listening;
    if (wasListening) await stopListening();
    _currentLanguage = language;
    _currentMode = STTMode.none;

    try {
      final available = await _sherpaSTT.switchLanguage(language);
      _sherpaAvailable = available;
    } catch (_) {
      _sherpaAvailable = false;
    }
    _updateModeForLanguage(language);
    if (!wasListening && _currentMode == STTMode.none && _platformAvailable) {
      _currentMode = STTMode.platform;
    }
    if (wasListening) await startListening(language: language);
  }

  Future<bool> downloadModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) {
      _sherpaAvailable = await _sherpaSTT.initialize(language: language);
      _updateModeForLanguage(language);
    }
    return success;
  }

  bool isModelReady(String language) => _modelManager.isModelReady(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];
  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();
  List<String> get readyLanguages => _modelManager.readyLanguages;

  String get sttModeLabel {
    switch (_currentMode) {
      case STTMode.sherpaStreaming:
        return 'Offline (Streaming)';
      case STTMode.sherpaBatch:
        return 'Offline (Batch)';
      case STTMode.platform:
        return 'Online';
      case STTMode.demo:
        return 'Demo Mode';
      case STTMode.none:
        return 'Unavailable';
    }
  }

  String _getLocaleId(String language) {
    switch (language.toLowerCase()) {
      case 'urdu':
      case 'roman urdu':
        return 'ur-PK';
      case 'auto':
        // Conversational Mode can be used regardless of the app UI language.
        // Urdu is the preferred recognition locale for the bilingual speaker
        // flow; recognized script is surfaced as Urdu and Roman Urdu when the
        // provider returns Latin-script Urdu.
        return 'ur-PK';
      default:
        return 'en-US';
    }
  }

  String _detectLanguage(String text, {String fallback = 'English'}) {
    if (text.trim().isEmpty) return fallback;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'Urdu';

    final normalized = text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    const romanUrduWords = {
      'aap', 'ap', 'aapko', 'aapki', 'aapke', 'aapka', 'kya', 'kyun', 'hai', 'hain',
      'ho', 'mein', 'main', 'mujhe', 'tum', 'tumnay', 'se', 'ko', 'ka', 'ki', 'ke',
      'yeh', 'woh', 'ham', 'hum', 'mera', 'meri', 'mere', 'apna', 'nahi', 'nahin',
      'acha', 'achha', 'theek', 'karo', 'karna', 'jana', 'jao', 'chahiye', 'bhi', 'par',
    };
    final romanMatches = tokens.intersection(romanUrduWords).length;
    if (romanMatches >= 2 || (romanMatches == 1 && tokens.length <= 5)) {
      return 'Roman Urdu';
    }
    return 'English';
  }

  void dispose() {
    _platformRestartTimer?.cancel();
    _sherpaSubscription?.cancel();
    _platformSTT.cancel();
    _sherpaSTT.dispose();
    _controller.close();
    _modelManager.dispose();
  }
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

  bool get isOffline => mode == STTMode.sherpaStreaming || mode == STTMode.sherpaBatch;
  bool get isStreaming => mode == STTMode.sherpaStreaming;
  bool get isBatch => mode == STTMode.sherpaBatch;
  bool get isOnline => mode == STTMode.platform;
}
