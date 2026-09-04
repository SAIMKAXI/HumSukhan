import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/insight_normalizer.dart';
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
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final json = Map<String, dynamic>.from(data);
      final bullets = InsightNormalizer.dedupeSummary(
        InsightNormalizer.list(json['summaryBullets']),
      );
      final actionItems = InsightNormalizer.dedupeActions(
        InsightNormalizer.list(json['actionItems']),
      );
      final deadlines = InsightNormalizer.dedupeDeadlines(
        InsightNormalizer.list(json['deadlines']),
      );
      final mentionedPeople = InsightNormalizer.dedupePeople(
        InsightNormalizer.list(json['mentionedPeople']),
      );

      // The summary is authoritative only when Gemini returned structured bullets.
      // Never turn a legacy/free-form summary into a fake one-bullet "AI summary".
      if (bullets.isEmpty) return null;

      return ProfessionalInsight(
        sessionId: sessionId,
        summary: bullets.join(' '),
        summaryBullets: bullets,
        actionItems: actionItems,
        deadlines: deadlines,
        mentionedPeople: mentionedPeople,
        isAvailable: true,
      );
    } catch (e) {
      debugPrint('AI Edge Function error: $e');
      return null;
    }
  }
}
