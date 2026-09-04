import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/conversation_provider.dart';
import '../providers/everyday_speech_provider.dart';
import 'stt/enhanced_stt.dart';

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
    _subscription = speech.onResult.listen(_handleSpeechResult);
    unawaited(_loadPausePreference());
  }

  ConversationEngineState _state = ConversationEngineState.idle;
  ConversationEngineState get state => _state;

  Duration _pauseThreshold = ConversationPauseOptions.natural;
  Duration get pauseThreshold => _pauseThreshold;

  Timer? _silenceTimer;
  StreamSubscription<SpeechResultEvent>? _subscription;
  Future<void> _commandTail = Future<void>.value();
  bool _speechStarted = false;
  bool _turnStopping = false;
  int _turnGeneration = 0;
  String _latestTranscript = '';

  /// Finalized utterances in the current turn that have not been committed
  /// as a caption yet. Interim results are appended to this rather than
  /// replacing it, so a turn can span several utterances.
  String _settledTurnText = '';
  String _latestLanguage = 'English';
  String? _errorMessage;

  String get errorMessage => _errorMessage ?? '';
  String get latestTranscript => _latestTranscript;
  bool get isListening => speech.isListening;
  bool get isManualPauseMode => _pauseThreshold == Duration.zero;
  bool get isBusy => _state == ConversationEngineState.startingMic || _state == ConversationEngineState.processingFinal;

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
    } catch (_) {}
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
    } catch (_) {}
  }

  void startConversation() {
    _enqueue(() async {
      _cancelSilenceTimer();
      _turnGeneration++;
      _turnStopping = false;
      _speechStarted = false;
      _latestTranscript = '';
      _settledTurnText = '';
      _latestLanguage = 'English';
      _errorMessage = null;
      _state = ConversationEngineState.idle;
      conversation.startConversation();
      notifyListeners();
      await speech.warmUpTts();
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
    _speechStarted = false;
    _latestTranscript = '';
    _settledTurnText = '';
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

  void stopListening() => _enqueue(_stopListening);

  Future<void> _stopListening() async {
    if (_turnStopping) return;
    _turnStopping = true;
    _cancelSilenceTimer();
    final generation = ++_turnGeneration;
    _state = ConversationEngineState.processingFinal;
    notifyListeners();

    try {
      await speech.stopListening();
      if (generation != _turnGeneration) return;

      _latestTranscript = _latestTranscript.trim();
      if (_latestTranscript.isNotEmpty) {
        conversation.updateSpeakerTurn(_latestTranscript, language: _latestLanguage);
      }
      conversation.commitSpeakerTurn();
      // Clear after committing: leaving the text here meant a later commit
      // could re-post the previous utterance as a duplicate caption.
      _latestTranscript = '';
      _settledTurnText = '';
      _speechStarted = false;
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

  /// Commits the utterance that just ended and immediately opens the next one,
  /// leaving the microphone running.
  ///
  /// A pause in speech ends an *utterance*, not the listening session: the UI
  /// says "Pause detected — speak again to continue", and the pause menu offers
  /// "Manual only — no auto-stop" as the alternative, so auto-stop is meant to
  /// segment turns rather than close the microphone. Wiring the silence timer
  /// straight to _stopListening() closed the microphone after the very first
  /// final result, so continuing to speak produced no further captions.
  Future<void> _finalizeTurn() async {
    if (_turnStopping) return;
    _cancelSilenceTimer();
    final transcript = _latestTranscript.trim();
    if (transcript.isEmpty) return;

    conversation.updateSpeakerTurn(transcript, language: _latestLanguage);
    conversation.commitSpeakerTurn();
    _latestTranscript = '';
    _settledTurnText = '';
    _speechStarted = false;

    final stillListening =
        speech.isListening && conversation.state == ConversationState.active;
    if (stillListening) {
      // Open a fresh draft so the next utterance becomes its own caption
      // instead of appending to the one just committed.
      conversation.beginSpeakerTurn(language: 'Auto');
      _state = ConversationEngineState.listening;
    } else {
      _state = ConversationEngineState.idle;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void speakLastUtterance() => _enqueue(_speakLastUtterance);

  Future<void> _speakLastUtterance() async {
    if (conversation.state != ConversationState.active) return;
    if (speech.isListening) await _stopListening();

    Caption? lastSpeakerCaption;
    for (final caption in conversation.captions.reversed) {
      if (!caption.isOwn && caption.text.trim().isNotEmpty) {
        lastSpeakerCaption = caption;
        break;
      }
    }
    if (lastSpeakerCaption == null) return;

    _state = ConversationEngineState.speaking;
    notifyListeners();
    try {
      await speech.speak(lastSpeakerCaption.text, language: lastSpeakerCaption.language);
    } finally {
      _state = ConversationEngineState.idle;
      notifyListeners();
    }
  }

  static String _joinTurn(String settled, String addition) =>
      settled.isEmpty ? addition : '$settled $addition';

  void _handleSpeechResult(SpeechResultEvent event) {
    final text = event.text.trim();
    if (text.isEmpty) return;
    // The recognizer clears its own buffer after each final result, so a final
    // carries only the utterance that just ended. Accumulate finals into the
    // turn instead of overwriting: replacing meant that speaking again before
    // the pause threshold elapsed silently discarded the previous utterance.
    _latestTranscript = _joinTurn(_settledTurnText, text);
    if (event.isFinal) _settledTurnText = _latestTranscript;
    _latestLanguage = event.language;
    if (_state == ConversationEngineState.listening) {
      _state = ConversationEngineState.speechActive;
    }
    _speechStarted = true;
    if (event.isFinal) {
      _cancelSilenceTimer();
      if (_pauseThreshold == Duration.zero) {
        _state = ConversationEngineState.speechActive;
      } else {
        _state = ConversationEngineState.waitingForTurnEnd;
        // Ends the utterance, not the microphone. Queued rather than called
        // directly so it serialises against start/stop/speak commands.
        _silenceTimer = Timer(_pauseThreshold, () => _enqueue(_finalizeTurn));
      }
    } else {
      _cancelSilenceTimer();
    }
    notifyListeners();
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
      conversation.stopConversation();
      _latestTranscript = '';
      _settledTurnText = '';
      _latestLanguage = 'English';
      _state = ConversationEngineState.idle;
      _errorMessage = null;
      notifyListeners();
    });
  }

  void dispose() {
    _cancelSilenceTimer();
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  void _enqueue(Future<void> Function() command) {
    _commandTail = _commandTail.then((_) => command()).catchError((Object error, StackTrace stack) {
      _errorMessage = 'Speech control failed.';
      _state = ConversationEngineState.error;
      debugPrint('ConversationEngine command error: $error\n$stack');
      notifyListeners();
    });
  }
}
