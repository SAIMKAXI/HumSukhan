import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/conversation_provider.dart';
import '../providers/everyday_speech_provider.dart';
import 'speech_engine.dart';
import 'stt/enhanced_stt.dart';
import 'turn_taking.dart';

enum ConversationEngineState {
  idle,
  startingMic,
  listening,
  speechActive,
  waitingForTurnEnd,
  processingFinal,
  speaking,
  error,
}

class ConversationPauseOptions {
  static const Duration fast = Duration(milliseconds: 1200);
  static const Duration natural = Duration(milliseconds: 1700);
  static const Duration patient = Duration(milliseconds: 2500);
  static const Duration manual = Duration.zero;
}

/// Deterministic orchestration for Conversational Mode.
class ConversationEngine extends ChangeNotifier {
  static const _pausePreferenceKey = 'conversationPauseMs';

  final EverydaySpeechProvider speech;
  final ConversationProvider conversation;

  ConversationEngine({required this.speech, required this.conversation}) {
    _subscription = speech.onResult.listen(_handleSpeechResult, onError: _handleSpeechInterrupted);
    _voiceSubscription = speech.onSpeechStarted.listen((_) => _handleVoiceStarted());
    unawaited(_loadPausePreference());
  }

  ConversationEngineState _state = ConversationEngineState.idle;
  ConversationEngineState get state => _state;

  Duration _pauseThreshold = ConversationPauseOptions.natural;
  Duration get pauseThreshold => _pauseThreshold;

  Timer? _silenceTimer;
  StreamSubscription<SpeechResultEvent>? _subscription;
  StreamSubscription<void>? _voiceSubscription;

  /// How this speaker pauses, learned during the conversation.
  final SpeakerPauses _pauses = SpeakerPauses();

  /// When the speaker last went quiet after a finished piece of speech, while
  /// waiting to see whether they carry on.
  DateTime? _pausedAt;

  /// Whether the speech after the last pause starts a new sentence, rather
  /// than carrying on one interrupted by a hesitation.
  bool _newSentence = false;

  /// Sounds that kept a pause open since the last words; see
  /// [_handleVoiceStarted].
  int _pauseExtensions = 0;
  static const int _maxPauseExtensions = 2;
  Future<void> _commandTail = Future<void>.value();
  bool _turnStopping = false;
  int _turnGeneration = 0;
  String _latestTranscript = '';

  String _settledTurnText = '';
  String _latestLanguage = 'English';
  String? _errorMessage;
  bool _disposed = false;

  String get errorMessage => _errorMessage ?? '';
  String get latestTranscript => _latestTranscript;
  bool get isListening => speech.isListening;
  bool get isManualPauseMode => _pauseThreshold == Duration.zero;
  bool get isBusy =>
      _state == ConversationEngineState.startingMic ||
      _state == ConversationEngineState.processingFinal ||
      _state == ConversationEngineState.speaking;

  bool get _live =>
      _state == ConversationEngineState.listening ||
      _state == ConversationEngineState.speechActive ||
      _state == ConversationEngineState.waitingForTurnEnd;

  String get statusLabel {
    switch (_state) {
      case ConversationEngineState.idle:
        return 'Ready — tap the microphone to speak';
      case ConversationEngineState.startingMic:
        return 'Starting microphone…';
      case ConversationEngineState.listening:
        return 'Listening — waiting for speech';
      case ConversationEngineState.speechActive:
        return 'Listening — speaker talking';
      case ConversationEngineState.waitingForTurnEnd:
        return 'Pause detected — speak again to continue';
      case ConversationEngineState.processingFinal:
        return 'Finishing the sentence…';
      case ConversationEngineState.speaking:
        return 'Speaking…';
      case ConversationEngineState.error:
        return _errorMessage ?? 'Speech error';
    }
  }

  Future<void> _loadPausePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_pausePreferenceKey);
      if (value == null) return;
      if (value == 0) {
        _pauseThreshold = ConversationPauseOptions.manual;
      } else {
        _pauseThreshold = Duration(milliseconds: value.clamp(800, 4000));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationEngine pause preference load failed: $e');
    }
  }

  Future<void> setPauseThreshold(Duration duration) async {
    final clamped = duration == Duration.zero
        ? ConversationPauseOptions.manual
        : Duration(milliseconds: duration.inMilliseconds.clamp(800, 4000));
    _pauseThreshold = clamped;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pausePreferenceKey, clamped.inMilliseconds);
    } catch (e) {
      debugPrint('ConversationEngine pause preference save failed: $e');
    }
  }

  void startConversation() {
    _enqueue(() async {
      _cancelSilenceTimer();
      _turnGeneration++;
      _turnStopping = false;
      _resetUtterance();
      _latestLanguage = 'English';
      _errorMessage = null;
      _state = ConversationEngineState.idle;
      conversation.startConversation();
      speech.holdMicrophoneForConversation(true);
      notifyListeners();
      // Not awaited: commands run in turn, and a tap on the microphone must
      // not wait for the voices to load.
      unawaited(speech.warmUpTts());
    });
  }

  void toggleListening() {
    if (speech.isListening ||
        _state == ConversationEngineState.speechActive ||
        _state == ConversationEngineState.waitingForTurnEnd ||
        _state == ConversationEngineState.listening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void startListening() => _enqueue(_startListening);

  Future<void> _startListening() async {
    if (conversation.state != ConversationState.active || speech.isListening || _turnStopping) return;

    _cancelSilenceTimer();
    final generation = ++_turnGeneration;
    _turnStopping = false;
    _resetUtterance();
    _latestLanguage = 'English';
    _errorMessage = null;
    _state = ConversationEngineState.startingMic;
    notifyListeners();

    conversation.beginSpeakerTurn(language: 'Auto');
    await speech.startListening(language: 'Auto');

    if (generation != _turnGeneration) return;
    if (!speech.isListening) {
      _state = ConversationEngineState.error;
      _errorMessage = speech.lastStartError ?? 'Live speech recognition could not be started.';
      conversation.commitSpeakerTurn();
      notifyListeners();
      return;
    }

    _state = ConversationEngineState.listening;
    notifyListeners();
  }

  void stopListening() {
    if (_disposed || _turnStopping) return;

    final shouldStop = speech.isListening ||
        _state == ConversationEngineState.startingMic ||
        _state == ConversationEngineState.listening ||
        _state == ConversationEngineState.speechActive ||
        _state == ConversationEngineState.waitingForTurnEnd;
    if (!shouldStop) return;

    _turnStopping = true;
    _cancelSilenceTimer();
    // Invalidate any in-flight startListening() operation immediately. The
    // public stop request must win even while microphone startup is waiting
    // on environmental-audio release or recognizer connection setup.
    _turnGeneration++;
    _state = ConversationEngineState.processingFinal;
    notifyListeners();
    _enqueue(_stopListening);
  }

  /// Recognition stopped by itself mid-turn and nothing could take over.
  /// Keep what was already captioned, and say why the microphone stopped
  /// rather than go on showing it as listening.
  void _handleSpeechInterrupted(Object error) {
    if (_disposed) return;
    final live = _state == ConversationEngineState.listening ||
        _state == ConversationEngineState.speechActive ||
        _state == ConversationEngineState.waitingForTurnEnd;
    if (!live) return;
    _cancelSilenceTimer();
    _turnGeneration++;
    final transcript = _latestTranscript.trim();
    if (transcript.isNotEmpty) {
      conversation.updateSpeakerTurn(transcript, language: _latestLanguage);
    }
    conversation.commitSpeakerTurn();
    _resetUtterance();
    _state = ConversationEngineState.error;
    _errorMessage = error is SpeechInterruption ? error.message : 'Live speech recognition stopped.';
    notifyListeners();
  }

  Future<void> _stopListening() async {
    final generation = _turnGeneration;

    try {
      await speech.stopListening();
      if (generation != _turnGeneration) return;

      _latestTranscript = _latestTranscript.trim();
      if (_latestTranscript.isNotEmpty) {
        conversation.updateSpeakerTurn(_latestTranscript, language: _latestLanguage);
      }
      conversation.commitSpeakerTurn();
      _resetUtterance();
      _state = ConversationEngineState.idle;
      _errorMessage = null;
    } catch (e) {
      if (generation != _turnGeneration) return;
      _state = ConversationEngineState.error;
      _errorMessage = 'Speech turn could not be finalized.';
      debugPrint('ConversationEngine stop error: $e');
    } finally {
      _turnStopping = false;
      notifyListeners();
    }
  }

  Future<void> _finalizeTurn() async {
    if (_turnStopping) return;
    _cancelSilenceTimer();
    final transcript = _latestTranscript.trim();
    if (transcript.isEmpty) return;

    conversation.updateSpeakerTurn(transcript, language: _latestLanguage);
    conversation.commitSpeakerTurn();
    _resetUtterance();

    final stillListening =
        speech.isListening && conversation.state == ConversationState.active;
    if (stillListening) {
      conversation.beginSpeakerTurn(language: 'Auto');
      _state = ConversationEngineState.listening;
    } else {
      _state = ConversationEngineState.idle;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _resetUtterance() {
    _latestTranscript = '';
    _settledTurnText = '';
    _pausedAt = null;
    _newSentence = false;
    _pauseExtensions = 0;
  }

  void _handleSpeechResult(SpeechResultEvent event) {
    if (_disposed || !_live) return;

    final text = event.text.trim();
    if (text.isEmpty) return;
    _carriedOn();
    _latestTranscript = TurnTaking.join(_settledTurnText, text, newSentence: _newSentence);
    if (event.isFinal) {
      _settledTurnText = _latestTranscript;
      _newSentence = false;
    }
    _latestLanguage = event.language;
    // Show the words as they are recognized; the pause only decides when
    // the caption is complete.
    conversation.updateSpeakerTurn(_latestTranscript, language: _latestLanguage);
    if (_state == ConversationEngineState.listening) {
      _state = ConversationEngineState.speechActive;
    }
    if (event.isFinal) {
      if (_pauseThreshold == Duration.zero) {
        _cancelSilenceTimer();
        _state = ConversationEngineState.speechActive;
      } else {
        _state = ConversationEngineState.waitingForTurnEnd;
        _pausedAt = DateTime.now();
        _pauseExtensions = 0;
        _armTurnEnd();
      }
    } else {
      _cancelSilenceTimer();
    }
    notifyListeners();
  }

  /// Words came after a pause: the speaker carried on. Learn how long they
  /// paused, and decide whether this starts a new sentence (the words before
  /// were a finished sentence) or carries on one broken by a hesitation.
  void _carriedOn() {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _pausedAt = null;
    _pauseExtensions = 0;
    _pauses.carriedOn(DateTime.now().difference(pausedAt));
    _newSentence = TurnTaking.completeness(_settledTurnText) == Completeness.complete;
  }

  /// Waits as long as the words so far call for: briefly after a finished
  /// sentence, longer when the speaker stopped on "and" or "کہ".
  void _armTurnEnd() {
    _cancelSilenceTimer();
    final wait = TurnTaking.pauseToEnd(_settledTurnText, base: _pauseThreshold, speakerPause: _pauses.typical);
    _silenceTimer = Timer(wait, () => _enqueue(_finalizeTurn));
  }

  /// The speaker made a sound during a pause, before any words came back:
  /// they are probably carrying on, so the pause is kept open a little
  /// longer. Only a couple of times, so a noisy room cannot hold a caption
  /// open for ever.
  void _handleVoiceStarted() {
    if (_disposed || _state != ConversationEngineState.waitingForTurnEnd) return;
    if (_pauseExtensions >= _maxPauseExtensions) return;
    _pauseExtensions++;
    _armTurnEnd();
  }

  /// The user replies, by typing or a quick reply, while the speaker may
  /// still be talking. The microphone stays on: what the speaker said so far
  /// becomes their caption, the reply follows it, and the speaker's next
  /// words start a new caption.
  void reply(String text) => _enqueue(() async {
        final value = text.trim();
        if (value.isEmpty || conversation.state != ConversationState.active) return;
        final live = _live && speech.isListening;
        _cancelSilenceTimer();
        conversation.addOwnCaption(value);
        _resetUtterance();
        if (live) {
          conversation.beginSpeakerTurn(language: 'Auto');
          _state = ConversationEngineState.listening;
        }
        notifyListeners();
      });

  /// Speaks [text] aloud. The microphone is off while it plays, or the app
  /// would caption its own voice; listening then carries on by itself.
  /// Completes when speaking ends, with the error if it failed.
  Future<void> speakReply(String text, {String language = 'Auto'}) {
    final done = Completer<void>();
    _enqueue(() async {
      final live = _live && speech.isListening;
      _cancelSilenceTimer();
      if (live) {
        final transcript = _latestTranscript.trim();
        if (transcript.isNotEmpty) conversation.updateSpeakerTurn(transcript, language: _latestLanguage);
        conversation.commitSpeakerTurn();
        _resetUtterance();
      }
      final generation = _turnGeneration;
      _state = ConversationEngineState.speaking;
      notifyListeners();
      Object? failure;
      StackTrace? failureStack;
      try {
        await speech.speak(text, language: language);
      } catch (e, st) {
        failure = e;
        failureStack = st;
      }
      if (live && generation == _turnGeneration && conversation.state == ConversationState.active) {
        // Stopping playback early skips the speech provider's own resume.
        if (!speech.isListening) await speech.startListening(language: 'Auto');
        if (speech.isListening) {
          conversation.beginSpeakerTurn(language: 'Auto');
          _state = ConversationEngineState.listening;
        } else {
          _state = ConversationEngineState.error;
          _errorMessage = speech.lastStartError ?? 'Live speech recognition could not be started.';
        }
      } else if (_state == ConversationEngineState.speaking) {
        _state = ConversationEngineState.idle;
      }
      notifyListeners();
      if (failure != null) {
        done.completeError(failure, failureStack);
      } else {
        done.complete();
      }
    });
    return done.future;
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void stopAndEndConversation() {
    _enqueue(() async {
      _cancelSilenceTimer();
      _turnGeneration++;
      await speech.stopListening();
      speech.holdMicrophoneForConversation(false);
      conversation.stopConversation();
      _resetUtterance();
      _latestLanguage = 'English';
      _state = ConversationEngineState.idle;
      _errorMessage = null;
      notifyListeners();
    });
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    speech.holdMicrophoneForConversation(false);
    _cancelSilenceTimer();
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_voiceSubscription?.cancel());
    _voiceSubscription = null;
    super.dispose();
  }

  void _enqueue(Future<void> Function() command) {
    if (_disposed) return;
    _commandTail = _commandTail.then((_) async {
      if (_disposed) return;
      await command();
    }).catchError((Object error, StackTrace stack) {
      if (_disposed) return;
      _errorMessage = 'Speech control failed.';
      _state = ConversationEngineState.error;
      debugPrint('ConversationEngine command error: $error\n$stack');
      notifyListeners();
    });
  }
}
