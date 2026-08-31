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
      final conversations = List<dynamic>.from(jsonDecode(prefs.getString('everydayConversations') ?? '[]'));
      final sorted = List<Caption>.from(_captions)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
    if (text.trim().isEmpty) return;
    _currentPartial = Caption(text: text, speaker: speaker, language: language, isPartial: true);
    _currentLanguage = language;
    notifyListeners();
  }

  void finalizeCaption(String text, {String speaker = 'Speaker 1', String language = 'English'}) {
    if (text.trim().isEmpty) return;
    final caption = Caption(text: text.trim(), speaker: speaker, language: language, isPartial: false);
    _captions.add(caption);
    _captions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _currentLanguage = language;
    _currentPartial = null;
    notifyListeners();
  }

  void addOwnCaption(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    _captions.add(Caption(text: value, speaker: 'You', language: _currentLanguage, isOwn: true));
    _captions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
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
}
