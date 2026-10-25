import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/conversation_provider.dart';
import '../providers/everyday_speech_provider.dart';
import 'speech_engine.dart';
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
    _subscription = speech.onResult.listen(_handleSpeechResult, onError: _handleSpeechInterrupted);
    unawaited(_loadPausePreference());
  }

  ConversationEngineState _state = ConversationEngineState.idle;
  ConversationEngineState get state => _state;

  Duration _pauseThreshold = ConversationPauseOptions.natural;
  Duration get pauseThreshold => _pauseThreshold;

  Timer? _silenceTimer;
  StreamSubscription<SpeechResultEvent>? _subscription;
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
      _latestTranscript = '';
      _settledTurnText = '';
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
    _latestTranscript = '';
    _settledTurnText = '';
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
      _latestTranscript = '';
      _settledTurnText = '';
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
    _latestTranscript = '';
    _settledTurnText = '';

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

  static String _joinTurn(String settled, String addition) =>
      settled.isEmpty ? addition : '$settled $addition';

  void _handleSpeechResult(SpeechResultEvent event) {
    if (_disposed) return;
    if (_state != ConversationEngineState.listening &&
        _state != ConversationEngineState.speechActive &&
        _state != ConversationEngineState.waitingForTurnEnd) {
      return;
    }

    final text = event.text.trim();
    if (text.isEmpty) return;
    _latestTranscript = _joinTurn(_settledTurnText, text);
    if (event.isFinal) _settledTurnText = _latestTranscript;
    _latestLanguage = event.language;
    // Show the words as they are recognized; the pause only decides when
    // the caption is complete.
    conversation.updateSpeakerTurn(_latestTranscript, language: _latestLanguage);
    if (_state == ConversationEngineState.listening) {
      _state = ConversationEngineState.speechActive;
    }
    if (event.isFinal) {
      _cancelSilenceTimer();
      if (_pauseThreshold == Duration.zero) {
        _state = ConversationEngineState.speechActive;
      } else {
        _state = ConversationEngineState.waitingForTurnEnd;
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
      speech.holdMicrophoneForConversation(false);
      conversation.stopConversation();
      _latestTranscript = '';
      _settledTurnText = '';
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
