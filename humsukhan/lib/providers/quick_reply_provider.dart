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

  String get _storageKey {
    final userId = SupabaseService.instance.userId;
    return userId.isEmpty ? 'quickReplies:guest' : 'quickReplies:$userId';
  }

  List<QuickReply> get replies => List.unmodifiable(_replies);
  bool get isLoading => _isLoading;

  List<QuickReply> get conversationReplies => _replies.where((r) => r.category == 'Conversation').toList();
  List<QuickReply> get responseReplies => _replies.where((r) => r.category == 'Response').toList();
  List<QuickReply> get favoriteReplies => _replies.where((r) => r.isFavorite).toList();

  /// Favourites first, then the replies the user wrote (newest first), then
  /// the built-in ones, so a reply just added or starred is the first thing
  /// seen during a conversation.
  List<QuickReply> get orderedReplies {
    final own = _replies.where((r) => !r.isFavorite && !_isDefault(r)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      ..._replies.where((r) => r.isFavorite),
      ...own,
      ..._replies.where((r) => !r.isFavorite && _isDefault(r)),
    ];
  }

  static final Set<String> _defaultTexts = {
    ...AppStrings.quickRepliesEn.map((r) => r.$1),
    ...AppStrings.quickRepliesUr.map((r) => r.$1),
  };

  static bool _isDefault(QuickReply reply) => _defaultTexts.contains(reply.text);

  late final Future<void> _loaded;

  QuickReplyProvider() {
    _loaded = _loadReplies();
  }

  Future<void> _loadReplies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      _currentLanguage = prefs.getString('appLanguage') ?? 'en';

      if (json != null) {
        _replies = (jsonDecode(json) as List).map((r) => QuickReply.fromJson(r)).toList();
      } else {
        _replies = _buildDefaultReplies(_currentLanguage);
        await _saveReplies();
      }

      if (SupabaseService.instance.isAuthenticated) await _syncFromCloud();
    } catch (e) {
      _replies = _buildDefaultReplies(_currentLanguage);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncFromCloud() async {
    try {
      final cloudReplies = await DatabaseService.instance.fetchQuickReplies();
      if (cloudReplies.isNotEmpty) {
        final localTexts = _replies.map((r) => r.text).toSet();
        for (final cr in cloudReplies) {
          if (localTexts.contains(cr.text)) continue;
          // A built-in reply saved in the other language is already here in
          // this one; only its star carries over.
          if (_isDefault(cr)) {
            if (cr.isFavorite) _starTranslationOf(cr.text);
            continue;
          }
          _replies.add(cr);
        }
        await _saveReplies();
        debugPrint('Quick replies synced from cloud: ${cloudReplies.length}');
      } else if (_replies.isNotEmpty) {
        await DatabaseService.instance.upsertQuickReplies(_replies);
      }
    } catch (e) {
      debugPrint('Quick replies cloud sync error: $e');
    }
  }

  void _starTranslationOf(String text) {
    for (final table in [AppStrings.quickRepliesEn, AppStrings.quickRepliesUr]) {
      final i = table.indexWhere((d) => d.$1 == text);
      if (i == -1) continue;
      final translations = {AppStrings.quickRepliesEn[i].$1, AppStrings.quickRepliesUr[i].$1};
      final idx = _replies.indexWhere((r) => translations.contains(r.text));
      if (idx != -1) _replies[idx] = _replies[idx].copyWith(isFavorite: true);
      return;
    }
  }

  List<QuickReply> _buildDefaultReplies(String langCode) {
    final data = langCode == 'ur' ? AppStrings.quickRepliesUr : AppStrings.quickRepliesEn;
    return data.map((r) => QuickReply(text: r.$1, category: r.$2)).toList();
  }

  /// Swaps the built-in replies for the other language's, keeping the user's
  /// own replies and which built-in ones are starred.
  Future<void> switchLanguage(String langCode) async {
    // Until the stored replies are loaded there is nothing to translate, and
    // switching would overwrite them with bare defaults.
    await _loaded;
    if (_currentLanguage == langCode) return;
    _currentLanguage = langCode;
    final from = langCode == 'ur' ? AppStrings.quickRepliesEn : AppStrings.quickRepliesUr;
    final to = langCode == 'ur' ? AppStrings.quickRepliesUr : AppStrings.quickRepliesEn;
    final starred = <int>{
      for (final r in _replies)
        if (r.isFavorite) ...[from.indexWhere((d) => d.$1 == r.text), to.indexWhere((d) => d.$1 == r.text)],
    };
    final defaults = [
      for (var i = 0; i < to.length; i++) QuickReply(text: to[i].$1, category: to[i].$2, isFavorite: starred.contains(i)),
    ];
    _replies = [...defaults, ..._replies.where((r) => !_isDefault(r))];
    notifyListeners();
    await _saveReplies();
  }

  /// Shows the change first: the cloud copy is a round trip behind.
  Future<void> _commit() async {
    notifyListeners();
    await _saveReplies();
  }

  Future<void> _saveReplies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_replies.map((r) => r.toJson()).toList()));
    if (SupabaseService.instance.isAuthenticated) await DatabaseService.instance.upsertQuickReplies(_replies);
  }

  Future<void> addReply(String text, {String category = 'General', bool isFavorite = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final existing = _replies.indexWhere((r) => r.text == trimmed);
    if (existing != -1) {
      // Adding a reply that is already there brings it to the front.
      _replies[existing] = _replies[existing].copyWith(isFavorite: isFavorite || _replies[existing].isFavorite);
    } else {
      _replies.add(QuickReply(text: trimmed, category: category, isFavorite: isFavorite));
    }
    await _commit();
  }

  Future<void> updateReply(String id, {String? text, String? category, bool? isFavorite}) async {
    final idx = _replies.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _replies[idx] = _replies[idx].copyWith(text: text, category: category, isFavorite: isFavorite);
      await _commit();
    }
  }

  Future<void> deleteReply(String id) async {
    _replies.removeWhere((r) => r.id == id);
    await _commit();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _replies.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _replies[idx] = _replies[idx].copyWith(isFavorite: !_replies[idx].isFavorite);
      await _commit();
    }
  }
}
