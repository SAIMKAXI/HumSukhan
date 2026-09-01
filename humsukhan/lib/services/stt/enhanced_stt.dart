import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'vosk_stt.dart';
import 'model_manager.dart';
import '../deepgram_transcription_service.dart';

export 'vosk_stt.dart' show STTMode;

class EnhancedSpeechProvider {
  final SpeechToText _platformSTT = SpeechToText();
  final SherpaSTTProvider _sherpaSTT = SherpaSTTProvider();
  final DeepgramTranscriptionService _deepgram = DeepgramTranscriptionService.instance;
  final StreamController<SpeechResultEvent> _controller = StreamController<SpeechResultEvent>.broadcast();
  final ModelManager _modelManager = ModelManager.instance;

  bool _initialized = false;
  bool _listening = false;
  bool _platformAvailable = false;
  bool _sherpaAvailable = false;
  bool _platformRestartInFlight = false;
  bool _deepgramAutoMode = false;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';
  String _platformLocale = 'en-US';
  String _platformLastText = '';
  String _lastEmittedPlatformText = '';
  String _lastEmittedDeepgramFinal = '';
  String? _lastStartError;
  StreamSubscription<SherpaSTTResult>? _sherpaSubscription;
  StreamSubscription<DeepgramTranscriptResult>? _deepgramSubscription;
  Timer? _platformRestartTimer;

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  bool get isAvailable => _platformAvailable || _sherpaAvailable;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;
  bool get isSherpaAvailable => _sherpaAvailable;
  bool get isPlatformAvailable => _platformAvailable;
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  bool get isDemoMode => _currentMode == STTMode.demo;
  String? get lastStartError => _lastStartError ?? _deepgram.lastStartError;

  Future<bool> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return isAvailable;
    _currentLanguage = preferredLanguage;
    await _modelManager.initialize();
    try {
      final sherpaLanguage = preferredLanguage.toLowerCase() == 'auto'
          ? (_modelManager.isModelReady('Urdu') ? 'Urdu' : 'English')
          : preferredLanguage;
      _sherpaAvailable = await _sherpaSTT.initialize(language: sherpaLanguage);
    } catch (e) {
      debugPrint('Sherpa STT init failed: $e');
      _sherpaAvailable = false;
    }
    try {
      _platformAvailable = await _platformSTT.initialize(
        onStatus: _onPlatformStatus,
        onError: (error) {
          debugPrint('Platform STT error: ${error.errorMsg}');
          if (_listening && _currentMode == STTMode.platform && !_deepgramAutoMode) {
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
    if (language.toLowerCase() == 'auto') {
      _currentMode = STTMode.platform;
      return;
    }
    if (_sherpaAvailable && _modelManager.isModelReady(language)) {
      final model = _modelManager.getBestModel(language);
      _currentMode = model?.isStreaming == true ? STTMode.sherpaStreaming : STTMode.sherpaBatch;
    } else if (_platformAvailable) {
      _currentMode = STTMode.platform;
    } else {
      _currentMode = STTMode.none;
    }
  }

  void _onPlatformStatus(String status) {
    if (!_listening || _currentMode != STTMode.platform || _deepgramAutoMode) return;
    if (status == 'notListening' || status == 'done') {
      final pending = _platformLastText.trim();
      if (pending.isNotEmpty && pending != _lastEmittedPlatformText) {
        _emitResult(
          pending,
          isFinal: true,
          language: _detectLanguage(pending, fallback: _currentLanguage),
          mode: STTMode.platform,
        );
        _lastEmittedPlatformText = pending;
      }
      _platformLastText = '';
      _schedulePlatformRestart(delay: const Duration(milliseconds: 350));
    }
  }

  void _emitResult(
    String text, {
    required bool isFinal,
    required String language,
    required STTMode mode,
  }) {
    final value = text.trim();
    if (value.isEmpty) return;
    _controller.add(SpeechResultEvent(
      text: value,
      isFinal: isFinal,
      confidence: 0.9,
      language: language,
      isLive: true,
      mode: mode,
    ));
  }

  void _schedulePlatformRestart({Duration delay = const Duration(milliseconds: 350)}) {
    if (!_listening || _currentMode != STTMode.platform || _deepgramAutoMode) return;
    if (_platformRestartTimer?.isActive == true || _platformRestartInFlight) return;
    _platformRestartTimer = Timer(delay, () async {
      _platformRestartTimer = null;
      if (!_listening || _currentMode != STTMode.platform || _platformRestartInFlight || _deepgramAutoMode) return;
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
        if (_listening && _currentMode == STTMode.platform && !_deepgramAutoMode) {
          _platformRestartTimer = Timer(const Duration(seconds: 1), () {
            _platformRestartTimer = null;
            _schedulePlatformRestart(delay: Duration.zero);
          });
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
    _lastStartError = null;
    _lastEmittedDeepgramFinal = '';
    _currentLanguage = language;
    _updateModeForLanguage(language);
    _listening = true;
    _platformLastText = '';
    _lastEmittedPlatformText = '';
    _deepgramAutoMode = language.toLowerCase() == 'auto';

    try {
      if (_deepgramAutoMode) {
        await _deepgramSubscription?.cancel();
        _deepgramSubscription = _deepgram.onResult.listen((result) {
          if (!_listening) return;
          // Interim results are intentionally hidden from Conversation Mode.
          // Only a speech-final utterance becomes user-visible text.
          if (!result.speechFinal) return;
          final detected = result.language == 'Auto'
              ? _detectLanguage(result.transcript, fallback: 'English')
              : result.language;
          final text = result.transcript.trim();
          if (text.isEmpty || text == _lastEmittedDeepgramFinal) return;
          _lastEmittedDeepgramFinal = text;
          _emitResult(text, isFinal: true, language: detected, mode: STTMode.platform);
        });

        final started = await _deepgram.start(language: 'auto');
        if (started) return;

        await _deepgramSubscription?.cancel();
        _deepgramSubscription = null;
        _deepgramAutoMode = false;
        if (_platformAvailable) {
          _currentMode = STTMode.platform;
          try {
            await _startPlatformListening('Auto');
            if (_platformSTT.isListening) return;
          } catch (e) {
            _lastStartError = 'Android speech recognition could not start: $e';
          }
        }
        _listening = false;
        _lastStartError ??= 'Live speech recognition could not start.';
        return;
      }

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
          _lastStartError = 'Speech recognition is unavailable for $language.';
          break;
      }
    } catch (e) {
      _lastStartError = 'Speech recognition could not start: $e';
      _listening = false;
      _deepgramAutoMode = false;
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
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    _platformLastText = text;
    if (result.finalResult) _lastEmittedPlatformText = text;
    _emitResult(
      text,
      isFinal: result.finalResult,
      language: _detectLanguage(text, fallback: _currentLanguage),
      mode: STTMode.platform,
    );
  }

  Future<void> stopListening() async {
    final useDeepgram = _deepgramAutoMode;
    _platformRestartTimer?.cancel();
    _platformRestartTimer = null;
    _platformRestartInFlight = false;
    _sherpaSubscription?.cancel();
    _sherpaSubscription = null;

    if (useDeepgram) {
      // Keep the logical listening state alive while Deepgram flushes its final
      // speech_final packet. The caller can then commit exactly one bubble.
      await _deepgram.stop();
      final flushed = _deepgram.lastFinalTranscript.trim();
      if (flushed.isNotEmpty && flushed != _lastEmittedDeepgramFinal) {
        _lastEmittedDeepgramFinal = flushed;
        _emitResult(
          flushed,
          isFinal: true,
          language: _detectLanguage(flushed, fallback: _currentLanguage),
          mode: STTMode.platform,
        );
      }
      _listening = false;
      _deepgramAutoMode = false;
      await _deepgramSubscription?.cancel();
      _deepgramSubscription = null;
      return;
    }

    _listening = false;
    _platformLastText = '';
    _lastEmittedPlatformText = '';
    if (_currentMode == STTMode.platform) {
      await _platformSTT.stop();
    } else if (_currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch) {
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
      final sherpaLanguage = language.toLowerCase() == 'auto'
          ? (_modelManager.isModelReady('Urdu') ? 'Urdu' : 'English')
          : language;
      _sherpaAvailable = await _sherpaSTT.switchLanguage(sherpaLanguage);
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
      final sherpaLanguage = language.toLowerCase() == 'auto' ? 'Urdu' : language;
      _sherpaAvailable = await _sherpaSTT.initialize(language: sherpaLanguage);
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
      case STTMode.sherpaStreaming: return 'Offline (Streaming)';
      case STTMode.sherpaBatch: return 'Offline (Batch)';
      case STTMode.platform: return 'Online';
      case STTMode.demo: return 'Demo Mode';
      case STTMode.none: return 'Unavailable';
    }
  }

  String _getLocaleId(String language) {
    switch (language.toLowerCase()) {
      case 'urdu':
      case 'roman urdu': return 'ur-PK';
      case 'auto': return 'en-US';
      default: return 'en-US';
    }
  }

  String _detectLanguage(String text, {String fallback = 'English'}) {
    if (text.trim().isEmpty) return fallback;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'Urdu';
    final normalized = text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    const romanUrduWords = {
      'aap','ap','aapko','aapki','aapke','aapka','kya','kyun','hai','hain','ho',
      'mein','main','mujhe','tum','tumnay','se','ko','ka','ki','ke','yeh','woh',
      'ham','hum','mera','meri','mere','apna','nahi','nahin','acha','achha',
      'theek','karo','karna','jana','jao','chahiye','bhi','par',
    };
    final romanMatches = tokens.intersection(romanUrduWords).length;
    if (romanMatches >= 2 || (romanMatches == 1 && tokens.length <= 5)) return 'Roman Urdu';
    return 'English';
  }

  void dispose() {
    _platformRestartTimer?.cancel();
    _sherpaSubscription?.cancel();
    _deepgramSubscription?.cancel();
    _platformSTT.cancel();
    _deepgram.cancel();
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
