import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class ConversationProvider extends ChangeNotifier {
  ConversationState _state = ConversationState.idle;
  final List<Caption> _captions = [];
  Caption? _currentPartial;
  Caption? _activeSpeakerDraft;
  Timer? _partialCommitTimer;
  String _isolateFingerprint = '';
  DateTime? _lastCommittedAt;
  bool _isListening = false;
  String _currentLanguage = 'English';
  String _listeningStatus = 'Not listening';
  DateTime? _conversationStartedAt;
  String? _currentSessionId;

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
    _isolateFingerprint = '';
    _lastCommittedAt = null;
    _state = ConversationState.active;
    _isListening = false;
    _conversationStartedAt = DateTime.now();
    _listeningStatus = 'Hold the microphone while the speaker talks';
    _currentSessionId = 'everyday_${DateTime.now().millisecondsSinceEpoch}';
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

  Future<void> saveConversation() async {
    _commitCurrentPartial();
    if (_captions.isEmpty) {
      _resetState();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = List<dynamic>.from(
        jsonDecode(prefs.getString('everydayConversations') ?? '[]'),
      );
      final sorted = _sortedCaptions();
      final session = {
        'id': _currentSessionId ?? 'everyday_${DateTime.now().millisecondsSinceEpoch}',
        'captions': sorted.map((c) => c.toJson()).toList(),
        'startedAt': _conversationStartedAt?.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
        'language': _currentLanguage,
      };
      conversations.add(session);
      await prefs.setString('everydayConversations', jsonEncode(conversations));

      if (SupabaseService.instance.isAuthenticated) {
        final transcript = sorted.map((c) => '${c.speaker}: ${c.text}').join('\n');
        final professionalSession = ProfessionalSession(
          id: _currentSessionId,
          title: 'Everyday Conversation — ${_formatDate(_conversationStartedAt)}',
          type: SessionType.meeting,
          captionLanguage: _currentLanguage,
          retentionDays: 7,
          status: SessionStatus.completed,
          captions: sorted,
          transcriptText: transcript,
        );
        await DatabaseService.instance.upsertSession(professionalSession);
      }
    } catch (e) {
      debugPrint('Error saving everyday conversation: $e');
    }
    _resetState();
  }

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
    _isolateFingerprint = '';
    _lastCommittedAt = null;
    _currentSessionId = null;
    notifyListeners();
  }

  void cancelStop() {
    _state = ConversationState.active;
    _isListening = false;
    _listeningStatus = 'Hold the microphone while the speaker talks';
    notifyListeners();
  }

  void beginSpeakerTurn({String language = 'English'}) {
    if (_state != ConversationState.active || _activeSpeakerDraft != null) return;
    _partialCommitTimer?.cancel();
    _currentLanguage = language;
    _isListening = true;
    _listeningStatus = 'Speaker is talking… release when finished';
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
    _activeSpeakerDraft = _activeSpeakerDraft!.copyWith(
      text: value,
      speaker: 'Speaker 1',
      isPartial: true,
    );
    if (_activeSpeakerDraft!.language != language) {
      _activeSpeakerDraft = Caption(
        id: _activeSpeakerDraft!.id,
        text: value,
        speaker: 'Speaker 1',
        timestamp: _activeSpeakerDraft!.timestamp,
        language: language,
        isPartial: true,
      );
    }
    _currentPartial = _activeSpeakerDraft;
    notifyListeners();
  }

  void commitSpeakerTurn({bool notify = true}) {
    final draft = _activeSpeakerDraft;
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    _activeSpeakerDraft = null;
    _currentPartial = null;
    _isListening = false;
    if (draft != null && draft.text.trim().isNotEmpty) {
      final committed = draft.copyWith(text: draft.text.trim(), isPartial: false);
      _captions.add(committed);
      _isolateFingerprint = _fingerprint(committed.text, committed.speaker);
      _lastCommittedAt = committed.timestamp;
      _sortCaptionsInPlace();
    }
    _listeningStatus = 'Your turn — respond below';
    if (notify) notifyListeners();
  }

  void addPartialCaption(
    String text, {
    String speaker = 'Speaker 1',
    String language = 'English',
  }) {
    final value = text.trim();
    if (value.isEmpty || _state != ConversationState.active) return;
    if (_currentPartial == null) {
      _beginPartial(value, speaker, language);
      return;
    }
    if (_currentPartial!.speaker != speaker) {
      _commitCurrentPartial();
      _beginPartial(value, speaker, language);
    } else if (_startsSameUtterance(_currentPartial!.text, value)) {
      _currentPartial = _currentPartial!.copyWith(text: value, isPartial: true);
      _restartPartialCommitTimer();
    } else {
      _commitCurrentPartial();
      _beginPartial(value, speaker, language);
    }
    _currentLanguage = language;
    notifyListeners();
  }

  void finalizeCaption(
    String text, {
    String speaker = 'Speaker 1',
    String language = 'English',
  }) {
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
      final committed = _currentPartial!.copyWith(text: value, isPartial: false);
      _captions.add(committed);
      _currentPartial = null;
      _isolateFingerprint = _fingerprint(value, speaker);
      _lastCommittedAt = committed.timestamp;
    } else {
      _commitCurrentPartial();
      _appendFinalCaption(value, speaker, language);
    }
    _currentLanguage = language;
    _sortCaptionsInPlace();
    notifyListeners();
  }

  void addOwnCaption(String text) {
    final value = text.trim();
    if (value.isEmpty || _state != ConversationState.active) return;
    commitSpeakerTurn(notify: false);
    _commitCurrentPartial();
    final caption = Caption(
      text: value,
      speaker: 'You',
      language: _currentLanguage,
      isOwn: true,
    );
    _captions.add(caption);
    _sortCaptionsInPlace();
    _listeningStatus = 'Hold the microphone when the speaker talks again';
    notifyListeners();
  }

  void clearCaptions() {
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    _captions.clear();
    _currentPartial = null;
    _activeSpeakerDraft = null;
    _isolateFingerprint = '';
    _lastCommittedAt = null;
    notifyListeners();
  }

  void _beginPartial(String text, String speaker, String language) {
    _partialCommitTimer?.cancel();
    final now = DateTime.now();
    _currentPartial = Caption(
      text: text,
      speaker: speaker,
      language: language,
      timestamp: now,
      isPartial: true,
    );
    _restartPartialCommitTimer();
  }

  void _restartPartialCommitTimer() {
    _partialCommitTimer?.cancel();
    _partialCommitTimer = Timer(const Duration(milliseconds: 1600), () {
      if (_state != ConversationState.active || _currentPartial == null) return;
      _commitCurrentPartial();
      notifyListeners();
    });
  }

  void _commitCurrentPartial() {
    _partialCommitTimer?.cancel();
    _partialCommitTimer = null;
    final partial = _currentPartial;
    if (partial == null || partial.text.trim().isEmpty) {
      _currentPartial = null;
      return;
    }
    final value = partial.text.trim();
    final fingerprint = _fingerprint(value, partial.speaker);
    if (_isolateFingerprint == fingerprint &&
        _lastCommittedAt != null &&
        DateTime.now().difference(_lastCommittedAt!).inMilliseconds < 1800) {
      _currentPartial = null;
      return;
    }
    final committed = partial.copyWith(text: value, isPartial: false);
    _captions.add(committed);
    _isolateFingerprint = fingerprint;
    _lastCommittedAt = committed.timestamp;
    _currentPartial = null;
    _sortCaptionsInPlace();
  }

  void _appendFinalCaption(String text, String speaker, String language) {
    final fingerprint = _fingerprint(text, speaker);
    if (_isolateFingerprint == fingerprint &&
        _lastCommittedAt != null &&
        DateTime.now().difference(_lastCommittedAt!).inMilliseconds < 1800) {
      return;
    }
    final caption = Caption(
      text: text,
      speaker: speaker,
      language: language,
      timestamp: DateTime.now(),
      isPartial: false,
    );
    _captions.add(caption);
    _isolateFingerprint = fingerprint;
    _lastCommittedAt = caption.timestamp;
  }

  bool _startsSameUtterance(String oldText, String newText) {
    final old = oldText.toLowerCase().trim();
    final next = newText.toLowerCase().trim();
    if (old.isEmpty || next.isEmpty) return true;
    if (next.startsWith(old) || old.startsWith(next)) return true;
    final oldTokens = _tokens(old);
    final newTokens = _tokens(next);
    if (oldTokens.isEmpty || newTokens.isEmpty) return true;
    final intersection = oldTokens.intersection(newTokens).length;
    final union = oldTokens.union(newTokens).length;
    final jaccard = union == 0 ? 1.0 : intersection / union;
    return jaccard >= 0.45;
  }

  Set<String> _tokens(String text) =>
      text.split(RegExp(r'\s+')).where((t) => t.length > 1).toSet();

  String _fingerprint(String text, String speaker) =>
      '${speaker.toLowerCase()}|${text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()}';

  List<Caption> _sortedCaptions() {
    final sorted = List<Caption>.from(_captions);
    sorted.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _sortCaptionsInPlace() {
    _captions.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _partialCommitTimer?.cancel();
    super.dispose();
  }
}
