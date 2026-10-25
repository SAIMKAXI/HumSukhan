import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/models.dart';
import '../services/everyday_bilingual_stt.dart';
import '../services/everyday_language_policy.dart';
import '../modules/environmental_alerts/services/environmental_monitor.dart';
import '../services/roman_urdu_detector.dart';
import '../services/speech_capability.dart';
import '../services/speech_engine.dart';
import '../services/stt/enhanced_stt.dart';
import '../services/stt/model_manager.dart';
import '../services/stt/stt_plan.dart';
import '../services/supabase_service.dart';
import 'speech_provider.dart' show ResilientTtsProvider;

/// Speech for both Everyday and Professional Mode.
///
/// Listening tries recognizers in the order `sttPlan` gives: the phone's own
/// recognizer when it has the language, then the cloud while there is a
/// connection, then a downloaded offline model. If the one running fails
/// mid-session, the next one takes over. There is one TTS implementation.
class EverydaySpeechProvider extends ChangeNotifier implements SpeechEngine {
  EverydaySpeechProvider({
    Future<bool> Function()? cloudReachable,
    @visibleForTesting EverydayBilingualSttService? cloudStream,
    @visibleForTesting EnhancedSpeechProvider? fallback,
    @visibleForTesting this.resumeDelay = monitoringResumeDelay,
    @visibleForTesting this.conversationResumeDelay = conversationMonitoringResumeDelay,
  })  : _cloudReachable = cloudReachable ?? _signedInAndOnline,
        _bilingual = cloudStream ?? EverydayBilingualSttService.instance,
        _fallbackStt = fallback ?? EnhancedSpeechProvider() {
    _modelProgress = _modelManager.onProgress.listen(_onModelProgress);
  }

  /// Whether the cloud speech services can be used, checked when listening
  /// starts so a phone with no connection goes straight to what works
  /// offline instead of waiting out every cloud timeout first.
  final Future<bool> Function() _cloudReachable;

  static Future<bool> _signedInAndOnline() async {
    if (!SupabaseService.instance.isAuthenticated) return false;
    try {
      final result = await InternetAddress.lookup('api.deepgram.com').timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final EverydayBilingualSttService _bilingual;
  final ResilientTtsProvider _ttsProvider = ResilientTtsProvider();
  final EnhancedSpeechProvider _fallbackStt;
  final StreamController<SpeechResultEvent> _results = StreamController<SpeechResultEvent>.broadcast();
  final ModelManager _modelManager = ModelManager.instance;
  final SpeechCapability _capability = SpeechCapability.instance;

  StreamSubscription<EverydayBilingualResult>? _bilingualSubscription;
  StreamSubscription<SpeechResultEvent>? _fallbackSubscription;
  StreamSubscription<String>? _connectionLostSubscription;
  bool _initialized = false;
  bool _listening = false;
  bool _startingListening = false;
  bool _usingFallback = false;
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
  String? get lastStartError => _lastStartError;
  LanguageResult? get detectedLanguage => _detected;
  STTMode get currentMode => _currentMode;
  bool get isPlatformAvailable => _fallbackStt.isPlatformAvailable;
  bool get isSherpaAvailable => _fallbackStt.isSherpaAvailable;
  bool get isOfflineMode => _currentMode == STTMode.sherpaStreaming || _currentMode == STTMode.sherpaBatch;
  bool get isStreamingMode => _currentMode == STTMode.sherpaStreaming;
  bool get isBatchMode => _currentMode == STTMode.sherpaBatch;
  bool get isOnlineMode => _currentMode == STTMode.platform;
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
        return activeSource == SpeechSource.device ? 'Device recognizer' : 'Online';
      case STTMode.cloudBatch:
        return 'Cloud (backup)';
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
        if ((_language == 'Urdu' || _language == 'Auto') && !_capability.sttSupportsUrduCached) {
          return 'Using cloud or offline fallback because Urdu is not installed in the device speech recognizer.';
        }
        return activeSource == SpeechSource.device
            ? 'Using the speech recognizer installed on this device.'
            : 'Online bilingual speech recognition.';
      case STTMode.cloudBatch:
        return 'This device has no speech recognizer for the language, so speech is recognized in the cloud after each pause.';
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

  /// Gets listening ready before the first tap on the microphone: the
  /// phone's recognizer and offline models are loaded and a cloud token is
  /// fetched, so starting only has to open the microphone and connect.
  Future<void> prepareListening() async {
    try {
      await Future.wait([
        _fallbackStt.initialize(),
        if (SupabaseService.instance.isAuthenticated) _bilingual.prewarm(),
      ]);
    } catch (e) {
      debugPrint('Speech warm-up failed: $e');
    }
  }

  Future<void> recheckSpeechCapabilities() async {
    await _fallbackStt.recheckPlatformCapabilities();
    await _ttsProvider.recheckMissingCapabilities();
    notifyListeners();
  }

  Future<void> startListening({String language = 'English'}) async {
    if (_listening || _startingListening) return;
    _startingListening = true;
    try {
      await initialize(preferredLanguage: language);
      if (_listening) return;

      // Environmental monitoring uses a dedicated native microphone capture
      // path, including when it was started from Quick Settings. Release that
      // capture completely before opening foreground speech recognition.
      _monitoringResume?.cancel();
      _language = _normalizeLanguage(language) == 'Roman Urdu' ? 'Urdu' : _normalizeLanguage(language);
      _lastStartError = null;
      _latestFinal = '';
      _detected = null;
      _usingFallback = false;

      // None of these depends on another. Run one after another, their
      // delays added up before the microphone could open.
      final ready = await Future.wait<bool>([
        EnvironmentalMonitoring.releaseForForegroundSpeech(),
        _cloudReachable(),
        _fallbackStt.initialize().then((_) => true),
      ]);
      if (!ready[0]) {
        throw StateError('Environmental monitoring could not release the microphone for speech recognition.');
      }
      final online = ready[1];
      _plan = sttPlan(
        language: _language,
        online: online,
        deviceHas: _fallbackStt.deviceSupports,
        offlineHas: _fallbackStt.offlineReady,
      );
      await _runPlan(from: 0);
      if (!_listening) {
        _scheduleMonitoringResume();
        _lastStartError ??= online
            ? 'Live speech recognition could not be started.'
            : 'No internet connection, and no offline speech model is downloaded for $_language. '
                'Download one in Settings to caption without a connection.';
        notifyListeners();
      }
    } finally {
      _startingListening = false;
    }
  }

  List<SpeechStep> _plan = const [];
  int _planStep = -1;

  /// The recognizer that is running, or null.
  SpeechSource? get activeSource => _listening && _planStep >= 0 && _planStep < _plan.length ? _plan[_planStep].source : null;

  /// Starts the first recognizer from step [from] of the plan that will run.
  Future<void> _runPlan({required int from}) async {
    for (var i = from; i < _plan.length && !_disposed; i++) {
      final step = _plan[i];
      final started = step.source == SpeechSource.cloudStream
          ? await _startCloudStream(step.language)
          : await _startFallbackStep(step);
      if (started) {
        _planStep = i;
        _listening = true;
        notifyListeners();
        return;
      }
      _lastStartError = step.source == SpeechSource.cloudStream ? _bilingual.lastStartError : _fallbackStt.lastStartError;
      debugPrint('Speech ${step.source.name} (${step.language}) did not start: $_lastStartError');
    }
    _planStep = -1;
    _listening = false;
    _currentMode = STTMode.none;
  }

  Future<bool> _startCloudStream(String language) async {
    await _bilingualSubscription?.cancel();
    _bilingualSubscription = _bilingual.onResult.listen(_handleResult);
    _connectionLostSubscription ??= _bilingual.onConnectionLost.listen(_onBilingualConnectionLost);
    if (await _bilingual.start(mode: language)) {
      _currentMode = STTMode.platform;
      return true;
    }
    await _bilingualSubscription?.cancel();
    _bilingualSubscription = null;
    return false;
  }

  /// The live cloud stream dropped, or stopped producing captions, and could
  /// not recover. Carry on with the next recognizer in the plan rather than
  /// leave the microphone open with nothing turning it into text; only if
  /// none starts is the conversation told that listening has stopped.
  Future<void> _onBilingualConnectionLost(String message) async {
    if (_disposed || !_listening || _usingFallback || _startingListening) return;
    final failed = _planStep;
    await _bilingualSubscription?.cancel();
    _bilingualSubscription = null;
    await _bilingual.stop();
    _listening = false;
    _lastStartError = message;
    await _runPlan(from: failed + 1);
    if (!_listening && !_results.isClosed) {
      _results.addError(SpeechInterruption(message));
    }
  }

  Future<bool> _startFallbackStep(SpeechStep step) async {
    await _fallbackSubscription?.cancel();
    _fallbackSubscription = _fallbackStt.onResult.listen((result) {
      if (!_listening && result.isFinal == false) return;
      final safe = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
      if (safe.isEmpty || _results.isClosed) return;
      final normalized = EverydayLanguagePolicy.normalizeRomanUrdu(safe);
      final detected = _detectCaptionLanguage(normalized, fallback: step.language);
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

    final route = switch (step.source) {
      SpeechSource.device => SttRoute.device,
      SpeechSource.cloudChunk => SttRoute.cloudChunk,
      _ => SttRoute.offline,
    };
    if (await _fallbackStt.start(route, language: step.language, bilingual: _language == 'Auto')) {
      _usingFallback = true;
      _currentMode = _fallbackStt.currentMode;
      return true;
    }
    await _fallbackSubscription?.cancel();
    _fallbackSubscription = null;
    return false;
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

  /// Environmental monitoring is restarted this long after listening stops,
  /// unless listening starts again first (a reply being spoken pauses and
  /// resumes listening, and must not bounce the microphone between the two).
  static const Duration monitoringResumeDelay = Duration(seconds: 3);

  /// The same, while a conversation is open. Restarting monitoring between
  /// every turn made each tap on the microphone wait for the monitoring
  /// service to stop again.
  static const Duration conversationMonitoringResumeDelay = Duration(seconds: 20);
  final Duration resumeDelay;
  final Duration conversationResumeDelay;
  Timer? _monitoringResume;
  bool _conversationOpen = false;

  /// A conversation has started ([open]) or ended. While one is open,
  /// monitoring resumes only after [conversationMonitoringResumeDelay] with
  /// no one speaking.
  void holdMicrophoneForConversation(bool open) {
    if (_disposed || _conversationOpen == open) return;
    _conversationOpen = open;
    if (!open && !_listening && !_startingListening) _scheduleMonitoringResume();
  }

  void _scheduleMonitoringResume() {
    _monitoringResume?.cancel();
    final delay = _conversationOpen ? conversationResumeDelay : resumeDelay;
    _monitoringResume = Timer(delay, () {
      if (_disposed || _listening || _startingListening || _speaking) return;
      // Android refuses to start a microphone service from the background;
      // SpeechLifecycleGuard resumes monitoring when the app is back.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      unawaited(EnvironmentalMonitoring.resumeAfterForegroundSpeech());
    });
  }

  @override
  Future<void> stopListening() async {
    _scheduleMonitoringResume();
    ++_speechGeneration;
    await _bilingual.stop();
    await _fallbackStt.stopListening();
    _listening = false;
    _usingFallback = false;
    _planStep = -1;
    await _bilingualSubscription?.cancel();
    await _fallbackSubscription?.cancel();
    _bilingualSubscription = null;
    _fallbackSubscription = null;
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    final wasListening = _listening;
    await stopListening();
    _language = _normalizeLanguage(language);
    _currentMode = STTMode.platform;
    if (wasListening) await startListening(language: _language);
    notifyListeners();
  }

  List<String> get offlineLanguages => ModelManager.availableModels.keys.toList();
  List<String> get readyLanguages => _modelManager.readyLanguages;
  bool isModelReady(String language) => _modelManager.isModelReady(language);
  ModelStatus? getModelStatus(String language) => _modelManager.statuses[language];

  /// Why the last download of [language]'s model failed, or null.
  String? modelError(String language) => _modelManager.lastError(language);

  late final StreamSubscription<ModelDownloadProgress> _modelProgress;

  void _onModelProgress(ModelDownloadProgress progress) {
    if (!_disposed) notifyListeners();
  }

  /// Downloads [language]'s offline model. Once it is on the phone the next
  /// start uses it whenever the phone's recognizer and the cloud cannot be
  /// used, with nothing more to set up.
  Future<bool> downloadOfflineModel(String language) async {
    final success = await _modelManager.downloadModel(language);
    if (success) await _fallbackStt.reloadOfflineModels();
    if (!_disposed) notifyListeners();
    return success;
  }

  Future<bool> deleteModel(String language) async {
    final success = await _modelManager.deleteModel(language);
    if (success) await _fallbackStt.reloadOfflineModels();
    if (!_disposed) notifyListeners();
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
    final wasListening = _listening;
    final resumeLanguage = _language;
    if (wasListening) await stopListening();

    // stopListening() advances _speechGeneration to invalidate recognizer work
    // from the previous listening session. The TTS operation owns a fresh
    // generation so its completion may safely resume that same session.
    final generation = ++_speechGeneration;

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
    final safe = language.trim();
    if (safe.isEmpty) return 'English';
    switch (safe.toLowerCase()) {
      case 'english':
      case 'en':
        return 'English';
      case 'urdu':
      case 'ur':
        return 'Urdu';
      case 'roman urdu':
      case 'roman_urdu':
        return 'Roman Urdu';
      case 'auto':
        return 'Auto';
      default:
        return safe;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _monitoringResume?.cancel();
    unawaited(_modelProgress.cancel());
    _cancelSubscriptions();
    unawaited(_results.close());
    _bilingual.stop();
    _fallbackStt.stopListening();
    _ttsProvider.dispose();
    _fallbackStt.dispose();
    super.dispose();
  }

  bool _disposed = false;

  void _cancelSubscriptions() {
    unawaited(_bilingualSubscription?.cancel());
    unawaited(_connectionLostSubscription?.cancel());
    _connectionLostSubscription = null;
    unawaited(_fallbackSubscription?.cancel());
    _bilingualSubscription = null;
    _fallbackSubscription = null;
  }
}

class _SpeechSegment {
  final String text;
  final String language;
  const _SpeechSegment(this.text, this.language);
}

/// Backwards-compatible constructor/type for existing screens and tests.
/// This is only a thin compatibility wrapper around the canonical Everyday
/// speech implementation; it contains no separate speech logic.
class SpeechProvider extends EverydaySpeechProvider {}
