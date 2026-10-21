import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

class ConversationProvider extends ChangeNotifier {
  ConversationState _state = ConversationState.idle;
  final List<Caption> _captions = [];
  Caption? _currentPartial;
  Caption? _activeSpeakerDraft;
  Timer? _partialCommitTimer;
  bool _isListening = false;
  String _currentLanguage = 'English';
  String _listeningStatus = 'Not listening';
  DateTime? _conversationStartedAt;


  ConversationState get state => _state;
  List<Caption> get captions => List.unmodifiable(_captions);
  Caption? get currentPartial => _currentPartial;
  bool get isListening => _isListening;
  bool get isSpeakerTurnActive => _activeSpeakerDraft != null || _isListening;
  String get currentLanguage => _currentLanguage;
  String get listeningStatus => _listeningStatus;
  DateTime? get conversationStartedAt => _conversationStartedAt;

  String get formattedDuration {
    if (_conversationStartedAt == null) return '0:00';
    final diff = DateTime.now().difference(_conversationStartedAt!);
    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void startConversation() {
    _partialCommitTimer?.cancel();
    _captions.clear();
    _currentPartial = null;
    _activeSpeakerDraft = null;
    _state = ConversationState.active;
    _isListening = false;
    _conversationStartedAt = DateTime.now();
    _listeningStatus = 'Tap the microphone to speak';
    notifyListeners();
  }

  void stopConversation() {
    commitSpeakerTurn(notify: false);
    _commitCurrentPartial();
    _state = ConversationState.stopping;
    _isListening = false;
    _listeningStatus = 'Stopping...';
    notifyListeners();
    _state = ConversationState.saveDecision;
    _listeningStatus = 'Stopped';
    notifyListeners();
  }

  /// Clears the in-memory transcript. Conversational Mode never persists sessions.
  void deleteConversation() => _resetState();

  void _resetState() {
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    _state = ConversationState.idle;
    _isListening = false;
    _listeningStatus = 'Not listening';
    _conversationStartedAt = null;
    _captions.clear();
    _currentPartial = null;
    _activeSpeakerDraft = null;
    notifyListeners();
  }

  void cancelStop() {
    _state = ConversationState.active;
    _isListening = false;
    _listeningStatus = 'Tap the microphone to speak';
    notifyListeners();
  }

  void beginSpeakerTurn({String language = 'English'}) {
    if (_state != ConversationState.active || _activeSpeakerDraft != null) return;
    _partialCommitTimer?.cancel();
    _currentLanguage = language;
    _isListening = true;
    _listeningStatus = 'Listening…';
    final now = DateTime.now();
    _activeSpeakerDraft = Caption(
      text: '',
      speaker: 'Speaker 1',
      language: language,
      timestamp: now,
      isPartial: true,
    );
    _currentPartial = _activeSpeakerDraft;
    notifyListeners();
  }

  void updateSpeakerTurn(String text, {String language = 'English'}) {
    final value = text.trim();
    if (value.isEmpty || _activeSpeakerDraft == null || _state != ConversationState.active) return;
    _currentLanguage = language;
    _activeSpeakerDraft = Caption(
      id: _activeSpeakerDraft!.id,
      text: value,
      speaker: 'Speaker 1',
      timestamp: _activeSpeakerDraft!.timestamp,
      language: language,
      isPartial: true,
    );
    _currentPartial = _activeSpeakerDraft;
    notifyListeners();
  }

  void commitSpeakerTurn({bool notify = true}) {
    // The draft text is already kept current by updateSpeakerTurn(), which the
    // caller feeds from the recognizer that is actually running. This used to
    // additionally overwrite the draft with the last final transcript of a
    // different recognizer, which held a stale utterance, so the transcript
    // kept repeating the first recognised phrase instead of the new speech.
    final draft = _activeSpeakerDraft;
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    _activeSpeakerDraft = null;
    _currentPartial = null;
    _isListening = false;
    if (draft != null && draft.text.trim().isNotEmpty) {
      final committed = Caption(
        id: draft.id,
        text: draft.text.trim(),
        speaker: draft.speaker,
        timestamp: draft.timestamp,
        language: draft.language,
        isPartial: false,
        isOwn: draft.isOwn,
      );
      _captions.add(committed);
      _sortCaptionsInPlace();
    }
    _listeningStatus = 'Your turn — respond below';
    if (notify) notifyListeners();
  }

  void addPartialCaption(String text, {String speaker = 'Speaker 1', String language = 'English'}) {
    final value = text.trim();
    if (value.isEmpty || _state != ConversationState.active) return;
    final existing = _currentPartial;
    if (existing == null || existing.speaker != speaker) {
      _partialCommitTimer?.cancel();
      _currentPartial = Caption(
        text: value,
        speaker: speaker,
        language: language,
        timestamp: existing?.timestamp ?? DateTime.now(),
        isPartial: true,
      );
    } else {
      _currentPartial = Caption(
        id: existing.id,
        text: value,
        speaker: existing.speaker,
        timestamp: existing.timestamp,
        language: language,
        isPartial: true,
        isOwn: existing.isOwn,
      );
    }
    _currentLanguage = language;
    notifyListeners();
  }

  void finalizeCaption(String text, {String speaker = 'Speaker 1', String language = 'English'}) {
    final value = text.trim();
    if (value.isEmpty || _state != ConversationState.active) return;
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;

    if (_activeSpeakerDraft != null && _activeSpeakerDraft!.speaker == speaker) {
      updateSpeakerTurn(value, language: language);
      commitSpeakerTurn();
      return;
    }

    if (_currentPartial != null && _currentPartial!.speaker == speaker) {
      final draft = _currentPartial!;
      final committed = Caption(
        id: draft.id,
        text: value,
        speaker: draft.speaker,
        timestamp: draft.timestamp,
        language: language,
        isPartial: false,
        isOwn: draft.isOwn,
      );
      _captions.add(committed);
      _currentPartial = null;
    } else {
      _commitCurrentPartial();
      _appendFinalCaption(value, speaker, language);
    }
    _currentLanguage = language;
    _sortCaptionsInPlace();
    notifyListeners();
  }

  void _appendFinalCaption(String text, String speaker, String language) {
    final committed = Caption(
      text: text.trim(),
      speaker: speaker,
      language: language,
      isPartial: false,
    );
    _captions.add(committed);
  }

  void addOwnCaption(String text) {
    final value = text.trim();
    if (value.isEmpty || _state != ConversationState.active) return;
    commitSpeakerTurn(notify: false);
    _commitCurrentPartial();
    final caption = Caption(text: value, speaker: 'You', language: _currentLanguage, isOwn: true);
    _captions.add(caption);
    _sortCaptionsInPlace();
    _listeningStatus = 'Tap the microphone to speak again';
    notifyListeners();
  }

  void _commitCurrentPartial() {
    final partial = _currentPartial;
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    _currentPartial = null;
    if (partial == null || partial.text.trim().isEmpty) return;
    final committed = Caption(
      id: partial.id,
      text: partial.text.trim(),
      speaker: partial.speaker,
      timestamp: partial.timestamp,
      language: partial.language,
      isPartial: false,
      isOwn: partial.isOwn,
    );
    _captions.add(committed);
    _sortCaptionsInPlace();
  }

  List<Caption> _sortedCaptions() {
    final copy = List<Caption>.from(_captions);
    copy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return copy;
  }

  void _sortCaptionsInPlace() {
    _captions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }


  @override
  void dispose() {
    _partialCommitTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
