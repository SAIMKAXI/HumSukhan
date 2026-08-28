import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

class ConversationProvider extends ChangeNotifier {
  ConversationState _state = ConversationState.idle;
  List<Caption> _captions = [];
  Caption? _currentPartial;
  bool _isListening = false;
  String _currentLanguage = 'English';
  String _listeningStatus = 'Not listening';
  DateTime? _conversationStartedAt;
  Timer? _listeningTimer;

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
    _state = ConversationState.starting;
    _listeningStatus = 'Starting...';
    notifyListeners();

    // Simulate brief startup
    Future.delayed(const Duration(milliseconds: 500), () {
      _state = ConversationState.active;
      _isListening = true;
      _conversationStartedAt = DateTime.now();
      _listeningStatus = 'Listening';
      notifyListeners();
    });
  }

  void stopConversation() {
    _state = ConversationState.stopping;
    _isListening = false;
    _listeningStatus = 'Stopping...';
    _currentPartial = null;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 300), () {
      _state = ConversationState.saveDecision;
      _listeningStatus = 'Stopped';
      notifyListeners();
    });
  }

  void saveConversation() {
    _state = ConversationState.idle;
    _listeningStatus = 'Not listening';
    _conversationStartedAt = null;
    _captions.clear();
    notifyListeners();
  }

  void deleteConversation() {
    _state = ConversationState.idle;
    _listeningStatus = 'Not listening';
    _conversationStartedAt = null;
    _captions.clear();
    _currentPartial = null;
    notifyListeners();
  }

  void cancelStop() {
    _state = ConversationState.active;
    _isListening = true;
    _listeningStatus = 'Listening';
    notifyListeners();
  }

  // Simulate receiving speech (for demo)
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

  @override
  void dispose() {
    _listeningTimer?.cancel();
    super.dispose();
  }
}
