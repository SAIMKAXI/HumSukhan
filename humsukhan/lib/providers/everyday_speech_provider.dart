import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/models.dart';
import '../services/cloud_tts_service.dart';
import '../services/everyday_bilingual_stt.dart';
import '../services/everyday_language_policy.dart';
import '../services/stt/enhanced_stt.dart';
import 'speech_provider.dart' as legacy;

/// Everyday Mode speech provider. It keeps the existing public contract while
/// replacing the unsupported single `multi` recognizer with English + Urdu.
class EverydaySpeechProvider extends legacy.SpeechProvider {
  final EverydayBilingualSttService _bilingual = EverydayBilingualSttService.instance;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  final StreamController<SpeechResultEvent> _results = StreamController<SpeechResultEvent>.broadcast();
  late final EnhancedSpeechProvider _statusProvider = _StatusSpeechProvider(this);

  StreamSubscription<EverydayBilingualResult>? _bilingualSubscription;
  bool _initialized = false;
  bool _listening = false;
  bool _speaking = false;
  String _language = 'Auto';
  String _lastSpoken = '';
  String _latestFinal = '';
  String? _lastStartError;
  LanguageResult? _detected;
  int _speechGeneration = 0;

  @override
  bool get isInitialized => _initialized;
  @override
  bool get isListening => _listening;
  @override
  bool get isSpeaking => _speaking;
  @override
  String get currentLanguage => _language;
  @override
  String get lastSpokenText => _lastSpoken;
  @override
  String get latestFinalText => _latestFinal;
  String? get lastStartError => _lastStartError ?? _bilingual.lastStartError;
  @override
  LanguageResult? get detectedLanguage => _detected;
  @override
  STTMode get currentMode => STTMode.platform;
  @override
  bool get isOfflineMode => false;
  @override
  bool get isStreamingMode => false;
  @override
  bool get isBatchMode => false;
  @override
  bool get isOnlineMode => _initialized;
  @override
  bool get isDemoMode => false;
  @override
  bool get isLiveStt => _listening;
  @override
  EnhancedSpeechProvider get sttProvider => _statusProvider;
  @override
  Stream<SpeechResultEvent> get onResult => _results.stream;

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {
    if (_initialized) return;
    _language = _normalizeLanguage(preferredLanguage);
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      try {
        await _tts.getVoices;
      } catch (_) {}
      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        _speaking = false;
        notifyListeners();
      });
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _lastStartError = 'Speech services could not initialize: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> warmUpTts() => initialize(preferredLanguage: _language);

  @override
  Future<void> startListening({String language = 'English'}) async {
    await initialize(preferredLanguage: language);
    if (_listening) return;
    _language = _normalizeLanguage(language);
    _lastStartError = null;
    _latestFinal = '';
    _detected = null;
    await _bilingualSubscription?.cancel();
    _bilingualSubscription = _bilingual.onResult.listen(_handleResult);

    final started = await _bilingual.start(mode: _language);
    if (!started) {
      _listening = false;
      _lastStartError = _bilingual.lastStartError ?? 'Live speech recognition could not be started.';
      await _bilingualSubscription?.cancel();
      _bilingualSubscription = null;
      notifyListeners();
      return;
    }
    _listening = true;
    notifyListeners();
  }

  void _handleResult(EverydayBilingualResult result) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(result.text).trim();
    if (safe.isEmpty) return;
    final output = _language == 'English'
        ? EverydayLanguagePolicy.toEnglishMode(safe)
        : EverydayLanguagePolicy.withBidiIsolation(safe);
    if (output.trim().isEmpty) return;

    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(safe);
    final hasEnglish = EverydayLanguagePolicy.containsLatin(safe);
    final language = hasUrdu && hasEnglish ? 'Auto' : hasUrdu ? 'Urdu' : 'English';
    _detected = LanguageResult(
      language: language,
      confidence: result.confidence,
      script: hasUrdu && hasEnglish ? 'Mixed' : hasUrdu ? 'Urdu' : 'Latin',
    );
    if (result.isFinal) _latestFinal = output;
    if (!_results.isClosed) {
      _results.add(SpeechResultEvent(
        text: output,
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
    _listening = false;
    await _bilingualSubscription?.cancel();
    _bilingualSubscription = null;
    notifyListeners();
  }

  @override
  Future<void> switchLanguage(String language) async {
    final wasListening = _listening;
    if (wasListening) await stopListening();
    _language = _normalizeLanguage(language);
    _lastStartError = null;
    notifyListeners();
    if (wasListening) await startListening(language: _language);
  }

  @override
  Future<void> switchToOnlineMode({String language = 'English'}) => switchLanguage(language);

  @override
  String processingLanguageForText(String text, {String fallback = 'English'}) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text);
    return EverydayLanguagePolicy.containsUrduScript(safe) ? 'Urdu' : 'English';
  }

  @override
  void detectLanguage(String text) {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text);
    final hasUrdu = EverydayLanguagePolicy.containsUrduScript(safe);
    final hasEnglish = EverydayLanguagePolicy.containsLatin(safe);
    final language = hasUrdu && hasEnglish ? 'Auto' : hasUrdu ? 'Urdu' : 'English';
    _detected = LanguageResult(
      language: language,
      confidence: hasUrdu && hasEnglish ? 0.85 : 0.9,
      script: hasUrdu && hasEnglish ? 'Mixed' : hasUrdu ? 'Urdu' : 'Latin',
    );
    notifyListeners();
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    final safe = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (safe.isEmpty) return;
    await initialize(preferredLanguage: language);
    final generation = ++_speechGeneration;
    await _stopPlaybackOnly(invalidate: false);
    _lastSpoken = safe;
    _speaking = true;
    notifyListeners();

    try {
      final requested = _normalizeLanguage(language);
      if (requested == 'English') {
        await _speakSegment(EverydayLanguagePolicy.toEnglishMode(safe), 'English', generation);
      } else {
        for (final segment in _splitForSpeech(safe)) {
          if (generation != _speechGeneration) return;
          await _speakSegment(segment.text, segment.language, generation);
        }
      }
    } finally {
      if (generation == _speechGeneration) {
        _speaking = false;
        notifyListeners();
      }
    }
  }

  List<_SpeechSegment> _splitForSpeech(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    final result = <_SpeechSegment>[];
    var current = 'english';
    var buffer = <String>[];
    void flush() {
      if (buffer.isNotEmpty) {
        result.add(_SpeechSegment(buffer.join(' '), current));
        buffer = <String>[];
      }
    }
    for (final token in tokens) {
      if (token.isEmpty) continue;
      final next = EverydayLanguagePolicy.containsUrduScript(token) ? 'urdu' : 'english';
      if (buffer.isNotEmpty && next != current) flush();
      current = next;
      buffer.add(token);
    }
    flush();
    return result;
  }

  Future<void> _speakSegment(String text, String language, int generation) async {
    if (text.trim().isEmpty || generation != _speechGeneration) return;
    final normalized = language.toLowerCase();
    final locales = normalized == 'urdu'
        ? const ['ur-PK', 'ur-IN']
        : const ['en-US', 'en-GB', 'en-IN'];
    var configured = false;
    for (final locale in locales) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true || available.toString().toLowerCase() == 'true') {
          await _tts.setLanguage(locale);
          configured = true;
          break;
        }
      } catch (_) {}
    }
    if (generation != _speechGeneration) return;
    if (configured) {
      try {
        await _tts.speak(text);
        var waited = 0;
        while (_speaking && generation == _speechGeneration && waited < 20000) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          waited += 40;
        }
        if (generation != _speechGeneration) return;
        if (_speaking) throw StateError('Device TTS timed out.');
        return;
      } catch (e) {
        debugPrint('Everyday native TTS failed ($normalized): $e');
      }
    }

    final result = await CloudTtsService.instance.synthesize(
      text: text,
      language: normalized == 'urdu' ? 'urdu' : 'english',
    );
    if (generation != _speechGeneration) return;
    final completion = _cloudPlayer.onPlayerStateChanged.firstWhere(
      (state) => state == PlayerState.completed || state == PlayerState.stopped,
    );
    await _cloudPlayer.play(BytesSource(Uint8List.fromList(result.audioBytes)));
    await completion.timeout(const Duration(seconds: 30));
  }

  Future<void> _stopPlaybackOnly({bool invalidate = true}) async {
    if (invalidate) ++_speechGeneration;
    try { await _cloudPlayer.stop(); } catch (_) {}
    try { await _tts.stop(); } catch (_) {}
    _speaking = false;
  }

  @override
  Future<void> stopSpeaking() async {
    await _stopPlaybackOnly();
    notifyListeners();
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
    unawaited(_bilingual.stop());
    unawaited(_cloudPlayer.dispose());
    unawaited(_tts.stop());
    unawaited(_results.close());
    _statusProvider.dispose();
    super.dispose();
  }
}

final class _SpeechSegment {
  const _SpeechSegment(this.text, this.language);

  final String text;
  final String language;
}

class _StatusSpeechProvider extends EnhancedSpeechProvider {
  final EverydaySpeechProvider owner;
  _StatusSpeechProvider(this.owner);
  @override
  bool get isListening => owner.isListening;
  @override
  String? get lastStartError => owner.lastStartError;
}

/// Preserve the existing `SpeechProvider()` constructor name for all consumers.
class SpeechProvider extends EverydaySpeechProvider {}
