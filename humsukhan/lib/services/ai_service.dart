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
        'generate-insights',
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
      return ProfessionalInsight(
        sessionId: sessionId,
        summary: json['summary']?.toString() ?? '',
        vocabulary: List<String>.from(json['vocabulary'] ?? const []),
        themes: List<String>.from(json['themes'] ?? const []),
        actionItems: List<String>.from(json['actionItems'] ?? const []),
        deadlines: List<String>.from(json['deadlines'] ?? const []),
        mentionedPeople: List<String>.from(json['mentionedPeople'] ?? const []),
        isAvailable: true,
      );
    } catch (e) {
      debugPrint('AI Edge Function error: $e');
      return null;
    }
  }
}
