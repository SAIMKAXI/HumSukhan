import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class QuickReplyProvider extends ChangeNotifier {
  List<QuickReply> _replies = [];
  bool _isLoading = false;

  List<QuickReply> get replies => List.unmodifiable(_replies);
  bool get isLoading => _isLoading;

  List<QuickReply> get conversationReplies =>
      _replies.where((r) => r.category == 'Conversation').toList();
  List<QuickReply> get responseReplies =>
      _replies.where((r) => r.category == 'Response').toList();
  List<QuickReply> get favoriteReplies =>
      _replies.where((r) => r.isFavorite).toList();

  static final _defaultReplies = [
    QuickReply(text: 'Hello', category: 'Conversation'),
    QuickReply(text: 'Thank you', category: 'Conversation'),
    QuickReply(text: 'Please wait', category: 'Conversation'),
    QuickReply(text: 'Please repeat that', category: 'Conversation'),
    QuickReply(text: 'Please type it', category: 'Conversation'),
    QuickReply(text: 'I did not understand', category: 'Conversation'),
    QuickReply(text: 'Yes', category: 'Response'),
    QuickReply(text: 'No', category: 'Response'),
    QuickReply(text: 'One moment, please', category: 'Response'),
    QuickReply(text: 'I need help', category: 'Response'),
  ];

  QuickReplyProvider() {
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('quickReplies');

      if (json != null) {
        _replies = (jsonDecode(json) as List)
            .map((r) => QuickReply.fromJson(r))
            .toList();
      } else {
        _replies = List.from(_defaultReplies);
        await _saveReplies();
      }
    } catch (e) {
      _replies = List.from(_defaultReplies);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveReplies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quickReplies', jsonEncode(_replies.map((r) => r.toJson()).toList()));
  }

  Future<void> addReply(String text, {String category = 'General'}) async {
    final reply = QuickReply(text: text, category: category);
    _replies.add(reply);
    await _saveReplies();
    notifyListeners();
  }

  Future<void> updateReply(String id, {String? text, String? category, bool? isFavorite}) async {
    final idx = _replies.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _replies[idx] = _replies[idx].copyWith(
        text: text,
        category: category,
        isFavorite: isFavorite,
      );
      await _saveReplies();
      notifyListeners();
    }
  }

  Future<void> deleteReply(String id) async {
    _replies.removeWhere((r) => r.id == id);
    await _saveReplies();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _replies.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _replies[idx] = _replies[idx].copyWith(isFavorite: !_replies[idx].isFavorite);
      await _saveReplies();
      notifyListeners();
    }
  }
}
