import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'cloud_chunk_stt.dart';
import 'vosk_stt.dart';
import 'model_manager.dart';
import '../everyday_language_policy.dart';
import '../speech_capability.dart';
import '../supabase_service.dart';

export 'vosk_stt.dart' show STTMode;

/// A way of turning the microphone into captions, other than the live cloud
/// stream, which EverydaySpeechProvider runs itself.
enum SttRoute {
  /// The phone's own recognizer, for a language it has installed.
  device,

  /// Each utterance recorded and recognized by the speech edge functions.
  cloudChunk,

  /// A downloaded on-device model; works with no connection.
  offline,
}

/// Runs one [SttRoute] at a time. The order they are tried in is decided by
/// the caller; see `sttPlan`.
class EnhancedSpeechProvider {
  EnhancedSpeechProvider({ModelManager? models}) : _modelManager = models ?? ModelManager.instance;

  final SpeechToText _platformSTT = SpeechToText();
  final SherpaSTTProvider _sherpaSTT = SherpaSTTProvider();
  final CloudChunkStt _cloudChunk = CloudChunkStt();
  StreamSubscription<CloudChunkResult>? _cloudChunkSubscription;
  final StreamController<SpeechResultEvent> _controller = StreamController<SpeechResultEvent>.broadcast();
  final ModelManager _modelManager;
  final SpeechCapability _capability = SpeechCapability.instance;

  bool _initialized = false;
  bool _listening = false;
  bool _platformAvailable = false;
  bool _platformRestartInFlight = false;
  STTMode _currentMode = STTMode.none;
  String _currentLanguage = 'English';
  String _platformLocale = 'en-US';
  String _platformLastText = '';
  String _lastEmittedPlatformText = '';
  String? _lastStartError;
  StreamSubscription<SherpaSTTResult>? _sherpaSubscription;
  Timer? _platformRestartTimer;

  Stream<SpeechResultEvent> get onResult => _controller.stream;
  bool get isListening => _listening;
  STTMode get currentMode => _currentMode;
  String get currentLanguage => _currentLanguage;
  bool get isSherpaAvailable => _modelManager.readyLanguages.isNotEmpty;
  bool get isPlatformAvailable => _platformAvailable;
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
  String? get lastStartError => _lastStartError;

  Future<void> initialize() async {
    if (_initialized) return;
    await _modelManager.initialize();
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
      if (_platformAvailable) {
        _platformAvailable = await _capability.probeStt(_platformSTT);
      }
    } catch (e) {
      debugPrint('Platform STT init failed: $e');
      _platformAvailable = false;
    }
    _initialized = true;
  }

  Future<void> recheckPlatformCapabilities() async {
    if (!_initialized) return;
    try {
      await _capability.recheckIfMissing(platformStt: _platformSTT);
      _platformAvailable = await _capability.sttAvailable();
    } catch (e) {
      debugPrint('Platform STT capability recheck failed: $e');
    }
  }

  /// The phone's recognizer has [language] installed.
  bool deviceSupports(String language) {
    if (!_platformAvailable) return false;
    final normalized = language.toLowerCase().trim();
    if (normalized == 'urdu' || normalized == 'ur' || normalized == 'roman urdu') {
      return _capability.sttSupportsUrduCached;
    }
    return _capability.sttSupportsEnglishCached;
  }

  /// A downloaded model can recognize [language] with no connection.
  bool offlineReady(String language) => _modelManager.isModelReady(language);

  /// A model was downloaded or deleted; use the new set from the next start.
  Future<void> reloadOfflineModels() async {
    if (_listening && isOfflineMode) await stopListening();
    await _sherpaSTT.reloadModels();
  }

  String _sanitizeOutput(String text) => EverydayLanguagePolicy.sanitizeHindi(text).trim();

  /// Starts [route] in [language]. [bilingual] asks the cloud route to
  /// recognize English and Urdu together. Returns whether it is listening;
  /// if not, [lastStartError] says why.
  Future<bool> start(SttRoute route, {required String language, bool bilingual = false}) async {
    await initialize();
    if (_listening) await stopListening();
    _lastStartError = null;
    _currentLanguage = language;
    _platformLastText = '';
    _lastEmittedPlatformText = '';
    _listening = true;

    try {
      switch (route) {
        case SttRoute.device:
          if (await _startPlatformListening(language)) return true;
        case SttRoute.cloudChunk:
          if (await _startCloudChunk(bilingual ? 'Auto' : language)) return true;
        case SttRoute.offline:
          if (await _startSherpa(language)) return true;
      }
    } catch (e) {
      _lastStartError = 'Speech recognition could not start: $e';
      debugPrint(_lastStartError);
    }
    _listening = false;
    _currentMode = STTMode.none;
    _lastStartError ??= 'Live speech recognition could not start.';
    return false;
  }

  Future<bool> _startCloudChunk(String language) async {
    if (!SupabaseService.instance.isAuthenticated) {
      _lastStartError = 'Sign in to use cloud speech recognition.';
      return false;
    }
    await _cloudChunkSubscription?.cancel();
    _cloudChunkSubscription = _cloudChunk.onResult.listen((result) {
      if (!_listening) return;
      final text = _sanitizeOutput(result.text);
      if (text.isEmpty) return;
      _emitResult(text, isFinal: true, language: result.language, mode: STTMode.cloudBatch);
    });
    if (await _cloudChunk.start(language: language)) {
      _currentMode = STTMode.cloudBatch;
      return true;
    }
    _lastStartError = _cloudChunk.lastStartError;
    await _cloudChunkSubscription?.cancel();
    _cloudChunkSubscription = null;
    return false;
  }

  Future<bool> _startSherpa(String language) async {
    if (!offlineReady(language)) {
      _lastStartError = 'No offline speech model is downloaded for $language.';
      return false;
    }
    await _sherpaSubscription?.cancel();
    _sherpaSubscription = _sherpaSTT.onResult.listen((result) {
      final text = _sanitizeOutput(result.text);
      if (text.isEmpty) return;
      final mode = _sherpaSTT.currentMode;
      _controller.add(SpeechResultEvent(
        text: text,
        isFinal: result.isFinal,
        confidence: result.confidence,
        language: _detectLanguage(text, fallback: language),
        isLive: true,
        mode: mode,
      ));
    });
    await _sherpaSTT.initialize(language: language);
    await _sherpaSTT.startListening(language: language);
    if (_sherpaSTT.isListening) {
      _currentMode = _sherpaSTT.currentMode;
      return true;
    }
    _lastStartError = 'The offline $language model could not be started.';
    await _sherpaSubscription?.cancel();
    _sherpaSubscription = null;
    return false;
  }

  void _onPlatformStatus(String status) {
    if (!_listening || _currentMode != STTMode.platform) return;
    if (status == 'notListening' || status == 'done') {
      final pending = _sanitizeOutput(_platformLastText);
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
      _schedulePlatformRestart(delay: const Duration(milliseconds: 200));
    }
  }

  void _emitResult(
    String text, {
    required bool isFinal,
    required String language,
    required STTMode mode,
  }) {
    final value = _sanitizeOutput(text);
    if (value.isEmpty || _controller.isClosed) return;
    final safeLanguage = EverydayLanguagePolicy.containsUrduScript(value)
        ? 'Urdu'
        : (language == 'Roman Urdu' ? 'Roman Urdu' : 'English');
    _controller.add(SpeechResultEvent(
      text: value,
      isFinal: isFinal,
      confidence: isFinal ? 0.9 : 0.7,
      language: safeLanguage,
      isLive: true,
      mode: mode,
    ));
  }

  void _schedulePlatformRestart({Duration delay = const Duration(milliseconds: 200)}) {
    if (!_listening || _currentMode != STTMode.platform) return;
    if (_platformRestartTimer?.isActive == true || _platformRestartInFlight) return;
    _platformRestartTimer = Timer(delay, () async {
      _platformRestartTimer = null;
      if (!_listening || _currentMode != STTMode.platform || _platformRestartInFlight) return;
      _platformRestartInFlight = true;
      try {
        await _platformSTT.listen(
          onResult: _onPlatformResult,
          listenOptions: _listenOptions(),
        );
      } catch (e) {
        debugPrint('Platform STT restart failed: $e');
        if (_listening && _currentMode == STTMode.platform) {
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

  SpeechListenOptions _listenOptions() => SpeechListenOptions(
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
        localeId: _platformLocale,
        cancelOnError: false,
        partialResults: true,
      );

  Future<bool> _startPlatformListening(String language) async {
    if (!deviceSupports(language)) {
      _lastStartError = language.toLowerCase().contains('urdu')
          ? 'Urdu is not installed for the device speech recognizer.'
          : 'English is not installed for the device speech recognizer.';
      return false;
    }
    final locale = await _capability.sttLocaleFor(_platformSTT, language);
    if (locale == null) {
      _lastStartError = 'No installed device recognizer locale for $language.';
      return false;
    }
    _platformLocale = locale;
    _currentMode = STTMode.platform;
    await _platformSTT.listen(onResult: _onPlatformResult, listenOptions: _listenOptions());
    // The recognizer reports that it is listening a moment after listen()
    // returns. Judging it on the spot treated every start as a failure and
    // opened a second recognizer on the same microphone.
    for (var i = 0; i < 15 && !_platformSTT.isListening; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_platformSTT.isListening) return true;
    try { await _platformSTT.cancel(); } catch (_) {}
    _lastStartError = 'The device speech recognizer did not start.';
    return false;
  }

  void _onPlatformResult(SpeechRecognitionResult result) {
    final text = _sanitizeOutput(result.recognizedWords);
    if (text.isEmpty) return;
    _platformLastText = text;
    _emitResult(
      text,
      isFinal: result.finalResult,
      language: _detectLanguage(text, fallback: _currentLanguage),
      mode: STTMode.platform,
    );
    if (result.finalResult) _lastEmittedPlatformText = text;
  }

  Future<void> stopListening() async {
    _platformRestartTimer?.cancel();
    _platformRestartTimer = null;
    _platformRestartInFlight = false;
    await _sherpaSubscription?.cancel();
    _sherpaSubscription = null;

    _listening = false;
    _platformLastText = '';
    _lastEmittedPlatformText = '';
    if (_currentMode == STTMode.cloudBatch) {
      // Transcribe what was still being said before going quiet.
      _listening = true;
      await _cloudChunk.stop();
      _listening = false;
      await _cloudChunkSubscription?.cancel();
      _cloudChunkSubscription = null;
    } else if (_currentMode == STTMode.platform) {
      try { await _platformSTT.stop(); } catch (_) {}
    } else if (_currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch) {
      await _sherpaSTT.stopListening();
    }
  }

  String get sttModeLabel {
    switch (_currentMode) {
      case STTMode.sherpaStreaming: return 'Offline (Streaming)';
      case STTMode.sherpaBatch: return 'Offline (Batch)';
      case STTMode.platform: return 'Online';
      case STTMode.cloudBatch: return 'Cloud (backup)';
      case STTMode.none: return 'Unavailable';
    }
  }

  String _detectLanguage(String text, {String fallback = 'English'}) {
    final safe = _sanitizeOutput(text);
    if (safe.trim().isEmpty) return fallback == 'Auto' ? 'English' : fallback;
    if (EverydayLanguagePolicy.containsUrduScript(safe)) return 'Urdu';
    final normalized = safe.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    const romanUrduWords = {
      'aap','ap','aapko','aapki','aapke','aapka','kya','kyun','hai','hain','ho',
      'mein','main','mujhe','tum','tumnay','se','ko','ka','ki','ke','yeh','woh',
      'ham','hum','mera','meri','mere','apna','nahi','nahin','acha','achha',
      'theek','karo','karna','jana','jao','chahiye','bhi','par',
    };
    final romanMatches = tokens.intersection(romanUrduWords).length;
    if (romanMatches >= 2 || (romanMatches == 1 && tokens.length <= 5)) return 'Roman Urdu';
    return fallback == 'Auto' ? 'English' : fallback;
  }

  void dispose() {
    _platformRestartTimer?.cancel();
    _sherpaSubscription?.cancel();
    _cloudChunkSubscription?.cancel();
    _platformSTT.cancel();
    _sherpaSTT.dispose();
    _controller.close();
    // The model manager is shared by the whole app and outlives this
    // provider, which is rebuilt whenever the signed-in account changes.
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
