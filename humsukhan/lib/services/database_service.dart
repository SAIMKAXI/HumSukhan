import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// Database service for Supabase CRUD operations.
///
/// Handles cloud persistence for:
/// - User profiles
/// - Settings
/// - Sessions (professional + everyday conversations)
/// - Session captions
/// - Folders
/// - AI insights
/// - Quick replies
///
/// All operations respect Row Level Security (RLS).
class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  SupabaseService get _supabase => SupabaseService.instance;

  bool get _isAvailable => _supabase.isReady && _supabase.client != null;

  // ──────────────────────────────────────────────
  // PROFILES
  // ──────────────────────────────────────────────

  /// Upsert user profile to Supabase.
  Future<void> upsertProfile(UserProfile profile) async {
    if (!_isAvailable) return;
    try {
      await _supabase.client!.from('profiles').upsert({
        'id': profile.id,
        'name': profile.name,
        'avatar_emoji': profile.avatarEmoji,
        'preferred_language': profile.preferredLanguage,
        'tutor_name': profile.tutorName,
        'created_at': profile.createdAt.toIso8601String(),
      });
      debugPrint('Profile upserted: ${profile.id}');
    } catch (e) {
      debugPrint('Profile upsert error: $e');
    }
  }

  /// Fetch user profile from Supabase.
  Future<UserProfile?> fetchProfile(String userId) async {
    if (!_isAvailable) return null;
    try {
      final data = await _supabase.client!
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile(
        id: data['id'],
        name: data['name'] ?? 'User',
        avatarEmoji: data['avatar_emoji'] ?? '👤',
        preferredLanguage: data['preferred_language'] ?? 'English',
        tutorName: data['tutor_name'] ?? 'Sam',
        createdAt: DateTime.parse(data['created_at']),
      );
    } catch (e) {
      debugPrint('Profile fetch error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // SETTINGS
  // ──────────────────────────────────────────────

  /// Upsert user settings.
  Future<void> upsertSettings(Map<String, dynamic> settings) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      await _supabase.client!.from('settings').upsert({
        'user_id': userId,
        'settings': settings,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Settings upserted for user: $userId');
    } catch (e) {
      debugPrint('Settings upsert error: $e');
    }
  }

  /// Fetch user settings.
  Future<Map<String, dynamic>?> fetchSettings(String userId) async {
    if (!_isAvailable) return null;
    try {
      final data = await _supabase.client!
          .from('settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return Map<String, dynamic>.from(data['settings'] ?? {});
    } catch (e) {
      debugPrint('Settings fetch error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // SESSIONS (Professional + Everyday)
  // ──────────────────────────────────────────────

  /// Upsert a professional session with its captions.
  Future<void> upsertSession(ProfessionalSession session) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      // Upsert session
      await _supabase.client!.from('sessions').upsert({
        'id': session.id,
        'user_id': userId,
        'title': session.title,
        'type': session.type.index,
        'folder_id': session.folderId,
        'caption_language': session.captionLanguage,
        'retention_days': session.retentionDays,
        'created_at': session.createdAt.toIso8601String(),
        'expires_at': session.expiresAt.toIso8601String(),
        'status': session.status.index,
        'transcript_text': session.transcriptText,
      });

      // Upsert captions
      if (session.captions.isNotEmpty) {
        final captionsData = session.captions.map((c) => {
          'id': c.id,
          'session_id': session.id,
          'user_id': userId,
          'text': c.text,
          'speaker': c.speaker,
          'timestamp': c.timestamp.toIso8601String(),
          'language': c.language,
          'is_partial': c.isPartial,
          'is_own': c.isOwn,
        }).toList();

        await _supabase.client!.from('captions').upsert(captionsData);
      }

      debugPrint('Session upserted: ${session.id}');
    } catch (e) {
      debugPrint('Session upsert error: $e');
    }
  }

  /// Fetch all sessions for the current user.
  Future<List<ProfessionalSession>> fetchSessions() async {
    if (!_isAvailable) return [];
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return [];

      final data = await _supabase.client!
          .from('sessions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final sessions = <ProfessionalSession>[];
      for (final row in data) {
        // Fetch captions for this session
        final captionsData = await _supabase.client!
            .from('captions')
            .select()
            .eq('session_id', row['id'])
            .order('timestamp');

        final captions = captionsData.map((c) => Caption(
          id: c['id'],
          text: c['text'] ?? '',
          speaker: c['speaker'] ?? 'Speaker 1',
          timestamp: DateTime.parse(c['timestamp']),
          language: c['language'] ?? 'English',
          isPartial: c['is_partial'] ?? false,
          isOwn: c['is_own'] ?? false,
        )).toList();

        sessions.add(ProfessionalSession(
          id: row['id'],
          title: row['title'] ?? '',
          type: SessionType.values[row['type'] ?? 0],
          folderId: row['folder_id'],
          captionLanguage: row['caption_language'] ?? 'English',
          retentionDays: row['retention_days'] ?? 7,
          createdAt: DateTime.parse(row['created_at']),
          expiresAt: DateTime.parse(row['expires_at']),
          status: SessionStatus.values[row['status'] ?? 1],
          captions: captions,
          transcriptText: row['transcript_text'],
        ));
      }

      debugPrint('Fetched ${sessions.length} sessions');
      return sessions;
    } catch (e) {
      debugPrint('Sessions fetch error: $e');
      return [];
    }
  }

  /// Delete a session and its captions.
  Future<void> deleteSession(String sessionId) async {
    if (!_isAvailable) return;
    try {
      // Delete captions first (foreign key)
      await _supabase.client!
          .from('captions')
          .delete()
          .eq('session_id', sessionId);

      // Delete associated insights
      await _supabase.client!
          .from('insights')
          .delete()
          .eq('session_id', sessionId);

      // Delete session
      await _supabase.client!
          .from('sessions')
          .delete()
          .eq('id', sessionId);

      debugPrint('Session deleted: $sessionId');
    } catch (e) {
      debugPrint('Session delete error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // FOLDERS
  // ──────────────────────────────────────────────

  /// Upsert a folder.
  Future<void> upsertFolder(Folder folder) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      await _supabase.client!.from('folders').upsert({
        'id': folder.id,
        'user_id': userId,
        'name': folder.name,
        'created_at': folder.createdAt.toIso8601String(),
      });
      debugPrint('Folder upserted: ${folder.id}');
    } catch (e) {
      debugPrint('Folder upsert error: $e');
    }
  }

  /// Fetch all folders.
  Future<List<Folder>> fetchFolders() async {
    if (!_isAvailable) return [];
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return [];

      final data = await _supabase.client!
          .from('folders')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      return data.map((row) => Folder(
        id: row['id'],
        name: row['name'] ?? '',
        createdAt: DateTime.parse(row['created_at']),
      )).toList();
    } catch (e) {
      debugPrint('Folders fetch error: $e');
      return [];
    }
  }

  /// Delete a folder.
  Future<void> deleteFolder(String folderId) async {
    if (!_isAvailable) return;
    try {
      await _supabase.client!
          .from('folders')
          .delete()
          .eq('id', folderId);
      debugPrint('Folder deleted: $folderId');
    } catch (e) {
      debugPrint('Folder delete error: $e');
    }
  }

  // ──────────────────────────────────────────────
  // INSIGHTS
  // ──────────────────────────────────────────────

  /// Upsert AI insight.
  Future<void> upsertInsight(ProfessionalInsight insight) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      await _supabase.client!.from('insights').upsert({
        'id': insight.id,
        'session_id': insight.sessionId,
        'user_id': userId,
        'summary': insight.summary,
        'vocabulary': insight.vocabulary,
        'themes': insight.themes,
        'action_items': insight.actionItems,
        'deadlines': insight.deadlines,
        'mentioned_people': insight.mentionedPeople,
        'generated_at': insight.generatedAt.toIso8601String(),
        'is_available': insight.isAvailable,
      });
      debugPrint('Insight upserted: ${insight.id}');
    } catch (e) {
      debugPrint('Insight upsert error: $e');
    }
  }

  /// Fetch insights for a session.
  Future<ProfessionalInsight?> fetchInsight(String sessionId) async {
    if (!_isAvailable) return null;
    try {
      final data = await _supabase.client!
          .from('insights')
          .select()
          .eq('session_id', sessionId)
          .maybeSingle();

      if (data == null) return null;
      return ProfessionalInsight(
        id: data['id'],
        sessionId: data['session_id'],
        summary: data['summary'] ?? '',
        vocabulary: List<String>.from(data['vocabulary'] ?? []),
        themes: List<String>.from(data['themes'] ?? []),
        actionItems: List<String>.from(data['action_items'] ?? []),
        deadlines: List<String>.from(data['deadlines'] ?? []),
        mentionedPeople: List<String>.from(data['mentioned_people'] ?? []),
        generatedAt: DateTime.parse(data['generated_at']),
        isAvailable: data['is_available'] ?? false,
      );
    } catch (e) {
      debugPrint('Insight fetch error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // QUICK REPLIES
  // ──────────────────────────────────────────────

  /// Upsert quick replies.
  Future<void> upsertQuickReplies(List<QuickReply> replies) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      // Delete existing and re-insert
      await _supabase.client!
          .from('quick_replies')
          .delete()
          .eq('user_id', userId);

      if (replies.isNotEmpty) {
        final data = replies.map((r) => {
          'id': r.id,
          'user_id': userId,
          'text': r.text,
          'category': r.category,
          'is_favorite': r.isFavorite,
          'created_at': r.createdAt.toIso8601String(),
        }).toList();

        await _supabase.client!.from('quick_replies').upsert(data);
      }
      debugPrint('Quick replies upserted: ${replies.length}');
    } catch (e) {
      debugPrint('Quick replies upsert error: $e');
    }
  }

  /// Fetch quick replies.
  Future<List<QuickReply>> fetchQuickReplies() async {
    if (!_isAvailable) return [];
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return [];

      final data = await _supabase.client!
          .from('quick_replies')
          .select()
          .eq('user_id', userId);

      return data.map((row) => QuickReply(
        id: row['id'],
        text: row['text'] ?? '',
        category: row['category'] ?? 'General',
        isFavorite: row['is_favorite'] ?? false,
        createdAt: DateTime.parse(row['created_at']),
      )).toList();
    } catch (e) {
      debugPrint('Quick replies fetch error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────
  // CLEANUP / RETENTION
  // ──────────────────────────────────────────────

  /// Delete expired sessions (both local and cloud).
  Future<int> cleanupExpiredSessions() async {
    if (!_isAvailable) return 0;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return 0;

      final now = DateTime.now().toIso8601String();

      // Find expired sessions
      final expired = await _supabase.client!
          .from('sessions')
          .select('id')
          .eq('user_id', userId)
          .lt('expires_at', now);

      if (expired.isEmpty) return 0;

      for (final session in expired) {
        await deleteSession(session['id']);
      }

      debugPrint('Cleaned up ${expired.length} expired sessions');
      return expired.length;
    } catch (e) {
      debugPrint('Cleanup error: $e');
      return 0;
    }
  }

  /// Delete ALL user data from Supabase.
  Future<void> deleteAllUserData() async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;

      // Delete in order (respect foreign keys)
      await _supabase.client!.from('captions').delete().eq('user_id', userId);
      await _supabase.client!.from('insights').delete().eq('user_id', userId);
      await _supabase.client!.from('sessions').delete().eq('user_id', userId);
      await _supabase.client!.from('folders').delete().eq('user_id', userId);
      await _supabase.client!.from('quick_replies').delete().eq('user_id', userId);
      await _supabase.client!.from('settings').delete().eq('user_id', userId);
      await _supabase.client!.from('profiles').delete().eq('id', userId);

      debugPrint('All user data deleted from Supabase');
    } catch (e) {
      debugPrint('Delete all data error: $e');
    }
  }
}
