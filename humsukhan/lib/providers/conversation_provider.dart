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

  String get _savedConversationsKey {
    final userId = SupabaseService.instance.userId;
    return userId.isEmpty ? 'everydayConversations:guest' : 'everydayConversations:$userId';
  }

  ConversationProvider() {
    unawaited(_syncSavedConversationsFromCloud());
  }

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

  Future<void> _syncSavedConversationsFromCloud() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    try {
      final cloudSessions = await DatabaseService.instance.fetchSessions();
      final saved = cloudSessions.where((s) => s.id.startsWith('everyday_'));
      if (saved.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString(_savedConversationsKey) ?? '[]');
      final local = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) local.add(Map<String, dynamic>.from(item));
        }
      }

      final byId = <String, Map<String, dynamic>>{
        for (final item in local)
          if (item['id']?.toString().isNotEmpty == true) item['id'].toString(): item,
      };

      for (final session in saved) {
        final existing = byId[session.id];
        byId[session.id] = {
          'id': session.id,
          'captions': session.captions.map((c) => c.toJson()).toList(),
          'startedAt': existing?['startedAt'] ?? session.createdAt.toIso8601String(),
          'savedAt': existing?['savedAt'] ?? session.createdAt.toIso8601String(),
          'language': session.captionLanguage,
        };
      }

      final merged = byId.values.toList()
        ..sort((a, b) => (b['savedAt']?.toString() ?? '').compareTo(a['savedAt']?.toString() ?? ''));
      await prefs.setString(_savedConversationsKey, jsonEncode(merged));
      debugPrint('Everyday conversations synced from cloud: ${saved.length}');
    } catch (e) {
      debugPrint('Everyday conversation cloud sync error: $e');
    }
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
    _listeningStatus = 'Tap the microphone to speak';
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
        jsonDecode(prefs.getString(_savedConversationsKey) ?? '[]'),
      );
      final sorted = _sortedCaptions();
      final sessionId = _currentSessionId ?? 'everyday_${DateTime.now().millisecondsSinceEpoch}';
      final session = {
        'id': sessionId,
        'captions': sorted.map((c) => c.toJson()).toList(),
        'startedAt': _conversationStartedAt?.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
        'language': _currentLanguage,
      };
      conversations.removeWhere((item) => item is Map && item['id']?.toString() == sessionId);
      conversations.add(session);
      await prefs.setString(_savedConversationsKey, jsonEncode(conversations));

      if (SupabaseService.instance.isAuthenticated) {
        final transcript = sorted.map((c) => '${c.speaker}: ${c.text}').join('\n');
        final professionalSession = ProfessionalSession(
          id: sessionId,
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
    // additionally overwrite the draft with
    // DeepgramTranscriptionService.instance.lastFinalTranscript -- a singleton
    // belonging to a *different* STT implementation (the EnhancedSpeechProvider
    // fallback) that Everyday Mode never starts, and which is only ever cleared
    // inside that service's own start(). So it held a stale utterance and every
    // committed caption was replaced by it, which is why the transcript kept
    // repeating the first recognised phrase instead of the new speech.
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
      _isolateFingerprint = _fingerprint(committed.text, committed.speaker);
      _lastCommittedAt = committed.timestamp;
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

  void _appendFinalCaption(String text, String speaker, String language) {
    final committed = Caption(
      text: text.trim(),
      speaker: speaker,
      language: language,
      isPartial: false,
    );
    _captions.add(committed);
    _isolateFingerprint = _fingerprint(committed.text, committed.speaker);
    _lastCommittedAt = committed.timestamp;
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
    _isolateFingerprint = _fingerprint(committed.text, committed.speaker);
    _lastCommittedAt = committed.timestamp;
    _sortCaptionsInPlace();
  }

  void commitCurrentPartial() {
    _commitCurrentPartial();
    notifyListeners();
  }

  List<Caption> _sortedCaptions() {
    final copy = List<Caption>.from(_captions);
    copy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return copy;
  }

  void _sortCaptionsInPlace() {
    _captions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  String _fingerprint(String text, String speaker) => '$speaker|${text.trim().toLowerCase()}';

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
