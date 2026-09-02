import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/conversation_provider.dart';
import '../providers/speech_provider.dart';

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
}

/// Deterministic orchestration for Conversational Mode.
///
/// Existing STT/TTS implementations remain underneath this controller. The
/// engine serializes mic operations, starts the silence timer only after speech
/// begins, and commits only after the speech provider has flushed its current
/// stream.
class ConversationEngine extends ChangeNotifier {
  static const _pausePreferenceKey = 'conversationPauseMs';

  final SpeechProvider speech;
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
  String? _errorMessage;

  String get errorMessage => _errorMessage ?? '';
  String get latestTranscript => _latestTranscript;
  bool get isListening => speech.isListening;
  bool get isBusy => _state == ConversationEngineState.startingMic ||
      _state == ConversationEngineState.processingFinal;

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
      if (value == null || value <= 0) return;
      _pauseThreshold = Duration(milliseconds: value.clamp(800, 4000));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPauseThreshold(Duration duration) async {
    final clamped = Duration(milliseconds: duration.inMilliseconds.clamp(800, 4000));
    _pauseThreshold = clamped;
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
    _errorMessage = null;
    _state = ConversationEngineState.startingMic;
    notifyListeners();

    conversation.beginSpeakerTurn(language: 'Auto');
    await speech.startListening(language: 'Auto');

    if (generation != _turnGeneration) return;
    if (!speech.isListening) {
      _state = ConversationEngineState.error;
      _errorMessage = speech.sttProvider.lastStartError ?? 'Live speech recognition could not be started.';
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

      _latestTranscript = speech.latestFinalText.trim();
      if (_latestTranscript.isNotEmpty) {
        final language = speech.detectedLanguage?.language ?? 'English';
        conversation.updateSpeakerTurn(_latestTranscript, language: language);
      }
      conversation.commitSpeakerTurn();
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
      _state = ConversationEngineState.idle;
    } catch (e) {
      _state = ConversationEngineState.error;
      _errorMessage = 'Text-to-speech could not play this caption.';
      debugPrint('ConversationEngine TTS error: $e');
    }
    notifyListeners();
  }

  void stopAndEndConversation() {
    _enqueue(() async {
      if (speech.isListening || conversation.isSpeakerTurnActive) {
        await _stopListening();
      }
      conversation.stopConversation();
      _cancelSilenceTimer();
      _speechStarted = false;
      _state = ConversationEngineState.idle;
      notifyListeners();
    });
  }

  void _handleSpeechResult(SpeechResultEvent result) {
    if (_turnStopping || conversation.state != ConversationState.active) return;
    final text = result.text.trim();
    if (text.isEmpty) return;

    _latestTranscript = text;
    _speechStarted = true;
    conversation.updateSpeakerTurn(text, language: _normalizeConversationLanguage(result.language));

    if (_state == ConversationEngineState.listening || _state == ConversationEngineState.waitingForTurnEnd) {
      _state = ConversationEngineState.speechActive;
    }

    _restartSilenceTimer();
    notifyListeners();
  }

  String _normalizeConversationLanguage(String language) {
    final value = language.toLowerCase();
    if (value.startsWith('ur') || value == 'roman urdu') return 'Urdu';
    return 'English';
  }

  void _restartSilenceTimer() {
    if (!_speechStarted || _turnStopping) return;
    _silenceTimer?.cancel();
    _state = ConversationEngineState.waitingForTurnEnd;
    _silenceTimer = Timer(_pauseThreshold, () {
      if (!_speechStarted || _turnStopping || !speech.isListening) return;
      stopListening();
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _enqueue(Future<void> Function() command) {
    _commandTail = _commandTail.then((_) => command()).catchError((Object error, StackTrace stack) {
      debugPrint('ConversationEngine command error: $error\n$stack');
      _state = ConversationEngineState.error;
      _errorMessage = 'Conversation audio operation failed.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _turnGeneration++;
    _cancelSilenceTimer();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
