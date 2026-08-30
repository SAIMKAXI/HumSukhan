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
  bool _isListening = false;
  String _currentLanguage = 'English';
  String _listeningStatus = 'Not listening';
  DateTime? _conversationStartedAt;
  Timer? _listeningTimer;
  String? _currentSessionId;

  // Getters
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
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void startConversation() {
    _state = ConversationState.active;
    _isListening = true;
    _conversationStartedAt = DateTime.now();
    _listeningStatus = 'Listening';
    _currentSessionId = _generateSessionId();
    notifyListeners();
  }

  String _generateSessionId() {
    final now = DateTime.now();
    return 'everyday_${now.millisecondsSinceEpoch}';
  }

  void stopConversation() {
    _state = ConversationState.stopping;
    _isListening = false;
    _listeningStatus = 'Stopping...';
    _currentPartial = null;
    notifyListeners();

    // Transition to save decision immediately
    _state = ConversationState.saveDecision;
    _listeningStatus = 'Stopped';
    notifyListeners();
  }

  /// Save the conversation to local storage and optionally to Supabase.
  Future<void> saveConversation() async {
    if (_captions.isEmpty) {
      // Nothing to save — just reset
      _resetState();
      return;
    }

    try {
      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString('everydayConversations') ?? '[]';
      final List<dynamic> conversations = jsonDecode(conversationsJson);

      final session = {
        'id': _currentSessionId ?? _generateSessionId(),
        'captions': _captions.map((c) => c.toJson()).toList(),
        'startedAt': _conversationStartedAt?.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
        'language': _currentLanguage,
      };

      conversations.add(session);
      await prefs.setString('everydayConversations', jsonEncode(conversations));

      // Sync to Supabase if authenticated
      if (SupabaseService.instance.isAuthenticated) {
        final transcript = _captions.map((c) => '${c.speaker}: ${c.text}').join('\n');
        final professionalSession = ProfessionalSession(
          title: 'Everyday Conversation — ${_formatDate(_conversationStartedAt)}',
          type: SessionType.meeting,
          captionLanguage: _currentLanguage,
          retentionDays: 7,
          status: SessionStatus.completed,
          captions: List.from(_captions),
          transcriptText: transcript,
        );
        await DatabaseService.instance.upsertSession(professionalSession);
      }

      debugPrint('Everyday conversation saved: ${_captions.length} captions');
    } catch (e) {
      debugPrint('Error saving everyday conversation: $e');
    }

    _resetState();
  }

  /// Delete the current conversation without saving.
  void deleteConversation() {
    _resetState();
  }

  void _resetState() {
    _state = ConversationState.idle;
    _listeningStatus = 'Not listening';
    _conversationStartedAt = null;
    _captions.clear();
    _currentPartial = null;
    _currentSessionId = null;
    notifyListeners();
  }

  void cancelStop() {
    _state = ConversationState.active;
    _isListening = true;
    _listeningStatus = 'Listening';
    notifyListeners();
  }

  void addPartialCaption(String text, {String speaker = 'Speaker 1', String language = 'English'}) {
    _currentPartial = Caption(
      text: text,
      speaker: speaker,
      language: language,
      isPartial: true,
    );
    _currentLanguage = language;
    notifyListeners();
  }

  void finalizeCaption(String text, {String speaker = 'Speaker 1', String language = 'English'}) {
    if (text.isNotEmpty) {
      _captions.add(Caption(
        text: text,
        speaker: speaker,
        language: language,
        isPartial: false,
      ));
    }
    _currentPartial = null;
    notifyListeners();
  }

  void addOwnCaption(String text) {
    if (text.isNotEmpty) {
      _captions.add(Caption(
        text: text,
        speaker: 'You',
        language: _currentLanguage,
        isOwn: true,
      ));
      notifyListeners();
    }
  }

  void clearCaptions() {
    _captions.clear();
    _currentPartial = null;
    notifyListeners();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    super.dispose();
  }
}
