import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../l10n/app_strings.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class QuickReplyProvider extends ChangeNotifier {
  List<QuickReply> _replies = [];
  bool _isLoading = false;
  String _currentLanguage = 'en';

  List<QuickReply> get replies => List.unmodifiable(_replies);
  bool get isLoading => _isLoading;

  List<QuickReply> get conversationReplies =>
      _replies.where((r) => r.category == 'Conversation').toList();
  List<QuickReply> get responseReplies =>
      _replies.where((r) => r.category == 'Response').toList();
  List<QuickReply> get favoriteReplies =>
      _replies.where((r) => r.isFavorite).toList();

  QuickReplyProvider() {
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('quickReplies');
      _currentLanguage = prefs.getString('appLanguage') ?? 'en';

      if (json != null) {
        _replies = (jsonDecode(json) as List)
            .map((r) => QuickReply.fromJson(r))
            .toList();
      } else {
        _replies = _buildDefaultReplies(_currentLanguage);
        await _saveReplies();
      }

      // Sync from Supabase if authenticated
      if (SupabaseService.instance.isAuthenticated) {
        await _syncFromCloud();
      }
    } catch (e) {
      _replies = _buildDefaultReplies(_currentLanguage);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sync replies from Supabase cloud.
  Future<void> _syncFromCloud() async {
    try {
      final cloudReplies = await DatabaseService.instance.fetchQuickReplies();
      if (cloudReplies.isNotEmpty) {
        // Merge: keep custom local replies, add cloud replies
        final localTexts = _replies.map((r) => r.text).toSet();
        for (final cr in cloudReplies) {
          if (!localTexts.contains(cr.text)) {
            _replies.add(cr);
          }
        }
        await _saveReplies();
        debugPrint('Quick replies synced from cloud: ${cloudReplies.length}');
      } else if (_replies.isNotEmpty) {
        // Push local replies to cloud
        await DatabaseService.instance.upsertQuickReplies(_replies);
      }
    } catch (e) {
      debugPrint('Quick replies cloud sync error: $e');
    }
  }

  List<QuickReply> _buildDefaultReplies(String langCode) {
    final data = langCode == 'ur'
        ? AppStrings.quickRepliesUr
        : AppStrings.quickRepliesEn;
    return data.map((r) => QuickReply(text: r.$1, category: r.$2)).toList();
  }

  /// Switch replies to a new language, replacing defaults.
  /// User-added custom replies are preserved.
  Future<void> switchLanguage(String langCode) async {
    if (_currentLanguage == langCode) return;
    _currentLanguage = langCode;

    final newDefaults = _buildDefaultReplies(langCode);

    // Keep only custom (non-default) replies, then add new language defaults
    final defaultTextsEn = AppStrings.quickRepliesEn.map<String>((r) => r.$1).toSet();
    final defaultTextsUr = AppStrings.quickRepliesUr.map<String>((r) => r.$1).toSet();
    final Set<String> allDefaultTexts = {...defaultTextsEn, ...defaultTextsUr};

    final customReplies = _replies
        .where((r) => !allDefaultTexts.contains(r.text))
        .toList();

    _replies = [...newDefaults, ...customReplies];
    await _saveReplies();
    notifyListeners();
  }

  Future<void> _saveReplies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quickReplies', jsonEncode(_replies.map((r) => r.toJson()).toList()));

    // Sync to Supabase if authenticated
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertQuickReplies(_replies);
    }
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
