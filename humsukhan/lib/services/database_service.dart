import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'supabase_service.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();
  SupabaseService get _supabase => SupabaseService.instance;
  bool get _isAvailable => _supabase.isReady && _supabase.client != null;

  Future<void> upsertProfile(UserProfile profile) async {
    if (!_isAvailable) return;
    try { await _supabase.client!.from('profiles').upsert({'id': profile.id, 'name': profile.name, 'avatar_emoji': profile.avatarEmoji, 'avatar_data': profile.avatarData, 'preferred_language': profile.preferredLanguage, 'tutor_name': profile.tutorName, 'created_at': profile.createdAt.toIso8601String()}); } catch (e) { debugPrint('Profile upsert error: $e'); }
  }
  Future<UserProfile?> fetchProfile(String userId) async {
    if (!_isAvailable) return null;
    try { final data = await _supabase.client!.from('profiles').select().eq('id', userId).maybeSingle(); if (data == null) return null; return UserProfile(id: data['id'], name: data['name'] ?? 'User', avatarEmoji: data['avatar_emoji'] ?? '👤', avatarData: data['avatar_data'], preferredLanguage: data['preferred_language'] ?? 'English', tutorName: data['tutor_name'] ?? 'Sam', createdAt: DateTime.parse(data['created_at'])); } catch (e) { debugPrint('Profile fetch error: $e'); return null; }
  }
  Future<void> upsertSettings(Map<String, dynamic> settings) async {
    if (!_isAvailable) return; try { final userId = _supabase.userId; if (userId.isEmpty) return; await _supabase.client!.from('settings').upsert({'user_id': userId, 'settings': settings, 'updated_at': DateTime.now().toIso8601String()}); } catch (e) { debugPrint('Settings upsert error: $e'); }
  }
  Future<Map<String, dynamic>?> fetchSettings(String userId) async {
    if (!_isAvailable) return null; try { final data = await _supabase.client!.from('settings').select().eq('user_id', userId).maybeSingle(); if (data == null) return null; return Map<String, dynamic>.from(data['settings'] ?? {}); } catch (e) { debugPrint('Settings fetch error: $e'); return null; }
  }
  Future<void> upsertSession(ProfessionalSession session) async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId; if (userId.isEmpty) return;
      await _supabase.client!.from('sessions').upsert({'id': session.id, 'user_id': userId, 'title': session.title, 'type': session.type.index, 'folder_id': session.folderId, 'caption_language': session.captionLanguage, 'retention_days': session.retentionDays, 'created_at': session.createdAt.toIso8601String(), 'expires_at': session.expiresAt.toIso8601String(), 'status': session.status.index, 'transcript_text': session.transcriptText});
      if (session.captions.isNotEmpty) await _supabase.client!.from('captions').upsert(session.captions.map((c) => {'id': c.id, 'session_id': session.id, 'user_id': userId, 'text': c.text, 'speaker': c.speaker, 'timestamp': c.timestamp.toIso8601String(), 'language': c.language, 'is_partial': c.isPartial, 'is_own': c.isOwn, 'segments': c.segments.map((s) => s.toJson()).toList()}).toList());
    } catch (e) { debugPrint('Session upsert error: $e'); }
  }
  Future<List<ProfessionalSession>> fetchSessions() async {
    if (!_isAvailable) return [];
    try {
      final userId = _supabase.userId; if (userId.isEmpty) return [];
      final data = await _supabase.client!.from('sessions').select().eq('user_id', userId).order('created_at', ascending: false);
      final sessions = <ProfessionalSession>[];
      for (final row in data) {
        final captionsData = await _supabase.client!.from('captions').select().eq('session_id', row['id']).order('timestamp');
        final captions = captionsData.map((c) {
          final rawSegments = c['segments'];
          final segments = rawSegments is List ? rawSegments.whereType<Map>().map((x) => CaptionSegment.fromJson(Map<String, dynamic>.from(x))).toList() : <CaptionSegment>[];
          return Caption(id: c['id'], text: c['text'] ?? '', speaker: c['speaker'] ?? 'Speaker 1', timestamp: DateTime.parse(c['timestamp']), language: c['language'] ?? 'English', isPartial: c['is_partial'] ?? false, isOwn: c['is_own'] ?? false, segments: segments);
        }).toList();
        sessions.add(ProfessionalSession(id: row['id'], title: row['title'] ?? '', type: SessionType.values[row['type'] ?? 0], folderId: row['folder_id'], captionLanguage: row['caption_language'] ?? 'English', retentionDays: row['retention_days'] ?? 7, createdAt: DateTime.parse(row['created_at']), expiresAt: DateTime.parse(row['expires_at']), status: SessionStatus.values[row['status'] ?? 1], captions: captions, transcriptText: row['transcript_text']));
      }
      return sessions;
    } catch (e) { debugPrint('Sessions fetch error: $e'); return []; }
  }
  Future<void> deleteSession(String sessionId) async {
    if (!_isAvailable) return;
    try { await _supabase.client!.from('captions').delete().eq('session_id', sessionId); await _supabase.client!.from('insights').delete().eq('session_id', sessionId); await _supabase.client!.from('sessions').delete().eq('id', sessionId); } catch (e) { debugPrint('Session delete error: $e'); }
  }
  Future<void> upsertFolder(Folder folder) async {
    if (!_isAvailable) return; try { await _supabase.client!.from('folders').upsert({'id': folder.id, 'user_id': _supabase.userId, 'name': folder.name, 'created_at': folder.createdAt.toIso8601String()}); } catch (e) { debugPrint('Folder upsert error: $e'); }
  }
  Future<List<Folder>> fetchFolders() async {
    if (!_isAvailable) return []; try { final data = await _supabase.client!.from('folders').select().eq('user_id', _supabase.userId).order('created_at'); return data.map((row) => Folder(id: row['id'], name: row['name'] ?? '', createdAt: DateTime.parse(row['created_at']))).toList(); } catch (e) { debugPrint('Folders fetch error: $e'); return []; }
  }
  Future<void> deleteFolder(String folderId) async {
    if (!_isAvailable) return;
    try { await _supabase.client!.rpc('delete_professional_folder', params: {'p_folder_id': folderId}); } catch (e) { debugPrint('Folder delete error: $e'); rethrow; }
  }
  Future<void> upsertInsight(ProfessionalInsight insight) async {
    if (!_isAvailable) return;
    try { await _supabase.client!.from('insights').upsert({'id': insight.id, 'session_id': insight.sessionId, 'user_id': _supabase.userId, 'summary': insight.summary, 'summary_bullets': insight.summaryBullets, 'action_items': insight.actionItems, 'deadlines': insight.deadlines, 'mentioned_people': insight.mentionedPeople, 'generated_at': insight.generatedAt.toIso8601String(), 'is_available': insight.isAvailable}); } catch (e) { debugPrint('Insight upsert error: $e'); }
  }
  Future<ProfessionalInsight?> fetchInsight(String sessionId) async {
    if (!_isAvailable) return null;
    try {
      final data = await _supabase.client!.from('insights').select().eq('session_id', sessionId).maybeSingle();
      if (data == null) return null;
      final raw = data['summary_bullets'];
      final bullets = raw is List ? raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : ((data['summary']?.toString().trim().isEmpty ?? true) ? <String>[] : [data['summary'].toString().trim()]);
      return ProfessionalInsight(id: data['id'], sessionId: data['session_id'], summary: data['summary'] ?? '', summaryBullets: bullets, actionItems: List<String>.from(data['action_items'] ?? []), deadlines: List<String>.from(data['deadlines'] ?? []), mentionedPeople: List<String>.from(data['mentioned_people'] ?? []), generatedAt: DateTime.parse(data['generated_at']), isAvailable: data['is_available'] ?? false);
    } catch (e) { debugPrint('Insight fetch error: $e'); return null; }
  }
  Future<void> upsertQuickReplies(List<QuickReply> replies) async {
    if (!_isAvailable) return; try { final userId = _supabase.userId; if (userId.isEmpty) return; await _supabase.client!.from('quick_replies').delete().eq('user_id', userId); if (replies.isNotEmpty) await _supabase.client!.from('quick_replies').upsert(replies.map((r) => {'id': r.id, 'user_id': userId, 'text': r.text, 'category': r.category, 'is_favorite': r.isFavorite, 'created_at': r.createdAt.toIso8601String()}).toList()); } catch (e) { debugPrint('Quick replies upsert error: $e'); }
  }
  Future<List<QuickReply>> fetchQuickReplies() async {
    if (!_isAvailable) return []; try { final data = await _supabase.client!.from('quick_replies').select().eq('user_id', _supabase.userId); return data.map((row) => QuickReply(id: row['id'], text: row['text'] ?? '', category: row['category'] ?? 'General', isFavorite: row['is_favorite'] ?? false, createdAt: DateTime.parse(row['created_at']))).toList(); } catch (e) { debugPrint('Quick replies fetch error: $e'); return []; }
  }
  Future<int> cleanupExpiredSessions() async {
    if (!_isAvailable) return 0; try { final rows = await _supabase.client!.from('sessions').select('id').eq('user_id', _supabase.userId).lt('expires_at', DateTime.now().toIso8601String()); for (final row in rows) await deleteSession(row['id']); return rows.length; } catch (e) { debugPrint('Cleanup error: $e'); return 0; }
  }
  Future<void> deleteAllUserData() async {
    if (!_isAvailable) return; try { final userId = _supabase.userId; if (userId.isEmpty) return; await _supabase.client!.from('captions').delete().eq('user_id', userId); await _supabase.client!.from('insights').delete().eq('user_id', userId); await _supabase.client!.from('sessions').delete().eq('user_id', userId); await _supabase.client!.from('folders').delete().eq('user_id', userId); await _supabase.client!.from('quick_replies').delete().eq('user_id', userId); await _supabase.client!.from('settings').delete().eq('user_id', userId); await _supabase.client!.from('profiles').delete().eq('id', userId); } catch (e) { debugPrint('Delete all data error: $e'); }
  }
}
