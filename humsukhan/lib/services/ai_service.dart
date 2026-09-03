import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// AI insight service. Gemini credentials remain server-side in Supabase.
class AiService {
  static AiService? _instance;
  static AiService get instance => _instance ??= AiService._();
  AiService._();

  bool get isAvailable => SupabaseService.instance.isReady;

  Future<ProfessionalInsight?> generateInsights({
    required String sessionId,
    required String transcript,
    required String sessionTitle,
    required SessionType sessionType,
  }) async {
    if (!isAvailable || transcript.trim().isEmpty) return null;
    try {
      final response = await SupabaseService.instance.client!.functions.invoke(
        'generate-insights-v2',
        body: {
          'sessionId': sessionId,
          'transcript': transcript,
          'sessionTitle': sessionTitle,
          'sessionType': sessionType.name,
          'model': EnvConfig.geminiModel,
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final json = Map<String, dynamic>.from(data);
      final rawBullets = json['summaryBullets'];
      final bullets = rawBullets is List
          ? rawBullets.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      final legacySummary = json['summary']?.toString().trim() ?? '';
      return ProfessionalInsight(
        sessionId: sessionId,
        summary: legacySummary,
        summaryBullets: bullets.isNotEmpty ? bullets : (legacySummary.isEmpty ? const [] : [legacySummary]),
        actionItems: _strings(json['actionItems']),
        deadlines: _strings(json['deadlines']),
        mentionedPeople: _strings(json['mentionedPeople']),
        isAvailable: bullets.isNotEmpty || legacySummary.isNotEmpty ||
            _strings(json['actionItems']).isNotEmpty || _strings(json['deadlines']).isNotEmpty,
      );
    } catch (e) {
      debugPrint('AI Edge Function error: $e');
      return null;
    }
  }

  List<String> _strings(dynamic value) => value is List
      ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
      : const [];
}
