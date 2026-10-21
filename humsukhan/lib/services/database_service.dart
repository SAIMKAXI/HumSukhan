import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/insight_normalizer.dart';
import 'supabase_service.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();
  SupabaseService get _supabase => SupabaseService.instance;
  bool get _isAvailable => _supabase.isReady && _supabase.client != null;

  Future<void> upsertProfile(UserProfile profile) async { if (!_isAvailable) return; try { await _supabase.client!.from('profiles').upsert({'id': profile.id, 'name': profile.name, 'avatar_emoji': profile.avatarEmoji, 'avatar_data': profile.avatarData, 'preferred_language': profile.preferredLanguage, 'tutor_name': profile.tutorName, 'created_at': profile.createdAt.toIso8601String()}); } catch (e) { debugPrint('Profile upsert error: $e'); } }
  Future<UserProfile?> fetchProfile(String userId) async { if (!_isAvailable) return null; try { final data = await _supabase.client!.from('profiles').select().eq('id', userId).maybeSingle(); if (data == null) return null; return UserProfile(id: data['id'], name: data['name'] ?? 'User', avatarEmoji: data['avatar_emoji'] ?? '👤', avatarData: data['avatar_data'], preferredLanguage: data['preferred_language'] ?? 'English', tutorName: data['tutor_name'] ?? 'Sam', createdAt: DateTime.parse(data['created_at'])); } catch (e) { debugPrint('Profile fetch error: $e'); return null; } }
  Future<void> upsertSettings(Map<String, dynamic> settings) async { if (!_isAvailable) return; try { final userId = _supabase.userId; if (userId.isEmpty) return; await _supabase.client!.from('settings').upsert({'user_id': userId, 'settings': settings, 'updated_at': DateTime.now().toIso8601String()}); } catch (e) { debugPrint('Settings upsert error: $e'); } }
  Future<Map<String, dynamic>?> fetchSettings(String userId) async { if (!_isAvailable) return null; try { final data = await _supabase.client!.from('settings').select().eq('user_id', userId).maybeSingle(); if (data == null) return null; return Map<String, dynamic>.from(data['settings'] ?? {}); } catch (e) { debugPrint('Settings fetch error: $e'); return null; } }
  Future<void> deleteInsight(String sessionId) async {
    if (!_isAvailable) return;
    try {
      await _supabase.client!.from('insights')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', _supabase.userId);
    } catch (e) {
      debugPrint('Insight delete error: $e');
    }
  }

  Future<void> upsertInsight(ProfessionalInsight insight, {required DateTime expiresAt}) async {
    if (!_isAvailable) return;
    final userId = _supabase.userId;
    if (userId.isEmpty) return;
    final normalized = ProfessionalInsight(
      id: insight.id,
      sessionId: insight.sessionId,
      summary: insight.summary,
      summaryBullets: InsightNormalizer.dedupeSummary(insight.summaryBullets),
      actionItems: InsightNormalizer.dedupeActions(insight.actionItems),
      deadlines: InsightNormalizer.dedupeDeadlines(insight.deadlines),
      mentionedPeople: InsightNormalizer.dedupePeople(insight.mentionedPeople),
      generatedAt: insight.generatedAt,
      isAvailable: insight.isAvailable,
    );
    try {
      await _supabase.client!.from('insights').upsert({
        'id': normalized.id,
        'session_id': normalized.sessionId,
        'user_id': userId,
        'summary': normalized.summary,
        'summary_bullets': normalized.summaryBullets,
        'action_items': normalized.actionItems,
        'deadlines': normalized.deadlines,
        'mentioned_people': normalized.mentionedPeople,
        'generated_at': normalized.generatedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'is_available': normalized.isAvailable,
      }, onConflict: 'session_id');
    } catch(e){debugPrint('Insight upsert error: $e');}
  }
  Future<ProfessionalInsight?> fetchInsight(String sessionId) async {
    if (!_isAvailable) return null;
    try {
      final data=await _supabase.client!.from('insights').select().eq('session_id', sessionId)
          .eq('user_id', _supabase.userId)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();
      if(data==null)return null;
      final rawBullets=data['summary_bullets'];
      final bullets=InsightNormalizer.dedupeSummary(
        rawBullets is List
            ? rawBullets.map((e)=>e.toString()).toList()
            : const [],
      );
      final actionItems=InsightNormalizer.dedupeActions(
        data['action_items'] is List
            ? (data['action_items'] as List).map((e)=>e.toString()).toList()
            : const [],
      );
      final deadlines=InsightNormalizer.dedupeDeadlines(
        data['deadlines'] is List
            ? (data['deadlines'] as List).map((e)=>e.toString()).toList()
            : const [],
      );
      final mentionedPeople=InsightNormalizer.dedupePeople(
        data['mentioned_people'] is List
            ? (data['mentioned_people'] as List).map((e)=>e.toString()).toList()
            : const [],
      );
      return ProfessionalInsight(id:data['id'],sessionId:data['session_id'],summary:bullets.join(' '),summaryBullets:bullets,actionItems:actionItems,deadlines:deadlines,mentionedPeople:mentionedPeople,generatedAt:DateTime.parse(data['generated_at']),isAvailable:data['is_available']??false);
    } catch(e){debugPrint('Insight fetch error: $e');return null;}
  }
  Future<void> upsertQuickReplies(List<QuickReply> replies) async { if(!_isAvailable)return; try{final userId=_supabase.userId;if(userId.isEmpty)return;await _supabase.client!.from('quick_replies').delete().eq('user_id',userId);if(replies.isNotEmpty)await _supabase.client!.from('quick_replies').upsert(replies.map((r)=>{'id':r.id,'user_id':userId,'text':r.text,'category':r.category,'is_favorite':r.isFavorite,'created_at':r.createdAt.toIso8601String()}).toList());}catch(e){debugPrint('Quick replies upsert error: $e');} }
  Future<List<QuickReply>> fetchQuickReplies() async { if(!_isAvailable)return [];try{final data=await _supabase.client!.from('quick_replies').select().eq('user_id',_supabase.userId);return data.map((row)=>QuickReply(id:row['id'],text:row['text']??'',category:row['category']??'General',isFavorite:row['is_favorite']??false,createdAt:DateTime.parse(row['created_at']))).toList();}catch(e){debugPrint('Quick replies fetch error: $e');return [];} }
  Future<void> deleteAllUserData() async {
    if (!_isAvailable) return;
    try {
      final userId = _supabase.userId;
      if (userId.isEmpty) return;
      await _supabase.client!.from('insights').delete().eq('user_id', userId);
      await _supabase.client!.from('quick_replies').delete().eq('user_id', userId);
      await _supabase.client!.from('settings').delete().eq('user_id', userId);
      await _supabase.client!.from('profiles').delete().eq('id', userId);
      // Deliberately do not delete auth.users here.
    } catch (e) {
      debugPrint('Delete user data error: $e');
    }
  }
}
