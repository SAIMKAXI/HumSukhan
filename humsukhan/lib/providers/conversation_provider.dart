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
  DateTime? _currentPartialStartedAt;
  DateTime? _lastCaptionTimestamp;
  bool _isListening = false;
  String _currentLanguage = 'English';
  String _listeningStatus = 'Not listening';
  DateTime? _conversationStartedAt;
  String? _currentSessionId;

  ConversationState get state => _state;
  List<Caption> get captions => List.unmodifiable(_captions);
  Caption? get currentPartial => _currentPartial;
  bool get isListening => _isListening;
  String get currentLanguage => _currentLanguage;
  String get listeningStatus => _listeningStatus;
  DateTime? get conversationStartedAt => _conversationStartedAt;

  String get formattedDuration {
    if (_conversationStartedAt == null) return '0:00';
    final diff = DateTime.now().difference(_conversationStartedAt!);
    return '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void startConversation() {
    _captions.clear();
    _currentPartial = null;
    _currentPartialStartedAt = null;
    _lastCaptionTimestamp = null;
    _state = ConversationState.active;
    _isListening = true;
    _conversationStartedAt = DateTime.now();
    _listeningStatus = 'Listening';
    _currentSessionId = 'everyday_${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();
  }

  void stopConversation() {
    _state = ConversationState.stopping;
    _isListening = false;
    _listeningStatus = 'Stopping...';
    _currentPartial = null;
    _currentPartialStartedAt = null;
    notifyListeners();
    _state = ConversationState.saveDecision;
    _listeningStatus = 'Stopped';
    notifyListeners();
  }

  Future<void> saveConversation() async {
    if (_captions.isEmpty) {
      _resetState();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = List<dynamic>.from(
        jsonDecode(prefs.getString('everydayConversations') ?? '[]'),
      );
      final sorted = List<Caption>.from(_captions)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
    _state = ConversationState.idle;
    _isListening = false;
    _listeningStatus = 'Not listening';
    _conversationStartedAt = null;
    _captions.clear();
    _currentPartial = null;
    _currentPartialStartedAt = null;
    _lastCaptionTimestamp = null;
    _currentSessionId = null;
    notifyListeners();
  }

  void cancelStop() {
    _state = ConversationState.active;
    _isListening = true;
    _listeningStatus = 'Listening';
    notifyListeners();
  }

  void addPartialCaption(
    String text, {
    String speaker = 'Speaker 1',
    String language = 'English',
  }) {
    final value = text.trim();
    if (value.isEmpty) return;

    // A partial result belongs to one utterance. Keep its original start time
    // so the finalized message retains the speaker's true chronological slot.
    _currentPartialStartedAt ??= DateTime.now();
    _currentPartial = Caption(
      text: value,
      speaker: speaker,
      language: language,
      timestamp: _currentPartialStartedAt,
      isPartial: true,
    );
    _currentLanguage = language;
    notifyListeners();
  }

  void finalizeCaption(
    String text, {
    String speaker = 'Speaker 1',
    String language = 'English',
  }) {
    final value = text.trim();
    if (value.isEmpty) return;

    // Use the beginning of the utterance rather than the recognition-final time.
    // This prevents a speaker's message from jumping below a user reply that
    // happened while the recognizer was finishing the speaker's sentence.
    final candidateTimestamp = _currentPartialStartedAt ?? DateTime.now();
    final timestamp = _monotonicTimestamp(candidateTimestamp);
    final caption = Caption(
      text: value,
      speaker: speaker,
      language: language,
      timestamp: timestamp,
      isPartial: false,
    );

    _captions.add(caption);
    _lastCaptionTimestamp = timestamp;
    _currentLanguage = language;
    _currentPartial = null;
    _currentPartialStartedAt = null;
    notifyListeners();
  }

  void addOwnCaption(String text) {
    final value = text.trim();
    if (value.isEmpty) return;

    final timestamp = _monotonicTimestamp(DateTime.now());
    _captions.add(
      Caption(
        text: value,
        speaker: 'You',
        language: _currentLanguage,
        timestamp: timestamp,
        isOwn: true,
      ),
    );
    _lastCaptionTimestamp = timestamp;
    notifyListeners();
  }

  DateTime _monotonicTimestamp(DateTime candidate) {
    final last = _lastCaptionTimestamp;
    if (last == null || candidate.isAfter(last)) return candidate;
    return last.add(const Duration(microseconds: 1));
  }

  void clearCaptions() {
    _captions.clear();
    _currentPartial = null;
    _currentPartialStartedAt = null;
    _lastCaptionTimestamp = null;
    notifyListeners();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
