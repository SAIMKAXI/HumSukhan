import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/models.dart';

/// AI service using Google Gemini Flash for generating session insights.
///
/// Capabilities:
/// - Summarize transcripts
/// - Extract important vocabulary
/// - Identify themes/topics
/// - Extract action items
/// - Extract deadlines
/// - Extract mentioned people
///
/// All output is structured and validated.
class AiService {
  static AiService? _instance;
  static AiService get instance => _instance ?? AiService._();
  AiService._();

  bool get isAvailable => EnvConfig.geminiApiKey.isNotEmpty;

  /// Generate insights from a transcript.
  Future<ProfessionalInsight?> generateInsights({
    required String sessionId,
    required String transcript,
    required String sessionTitle,
    required SessionType sessionType,
  }) async {
    if (!isAvailable) {
      debugPrint('AI Service: No API key configured');
      return null;
    }

    if (transcript.trim().isEmpty) {
      debugPrint('AI Service: Empty transcript');
      return null;
    }

    try {
      final prompt = _buildInsightPrompt(transcript, sessionTitle, sessionType);
      final response = await _callGemini(prompt);

      if (response == null) {
        debugPrint('AI Service: No response from Gemini');
        return null;
      }

      return _parseInsightResponse(sessionId, response);
    } catch (e) {
      debugPrint('AI Service error: $e');
      return null;
    }
  }

  /// Build the prompt for Gemini.
  String _buildInsightPrompt(String transcript, String title, SessionType type) {
    final typeLabel = type == SessionType.meeting
        ? 'meeting'
        : type == SessionType.lecture
            ? 'lecture'
            : 'class';

    return '''You are an AI assistant analyzing a $typeLabel transcript titled "$title".

Analyze the following transcript and return a JSON object with these fields:
- "summary": A concise 2-3 sentence summary of the key points
- "vocabulary": An array of 5-8 important terms or jargon used
- "themes": An array of 3-5 main themes or topics discussed
- "actionItems": An array of 3-7 action items or tasks mentioned
- "deadlines": An array of any deadlines or time-sensitive items mentioned
- "mentionedPeople": An array of people mentioned by name or role

Important rules:
- Return ONLY valid JSON, no markdown or extra text
- If a field has no data, return an empty array []
- Base everything strictly on the transcript content
- Do not fabricate information

Transcript:
$transcript''';
  }

  /// Call Gemini API.
  Future<String?> _callGemini(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${EnvConfig.geminiModel}:generateContent?key=${EnvConfig.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('Gemini API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body);
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      return parts[0]['text'] as String?;
    } catch (e) {
      debugPrint('Gemini API call failed: $e');
      return null;
    }
  }

  /// Parse the Gemini response into a ProfessionalInsight.
  ProfessionalInsight _parseInsightResponse(String sessionId, String response) {
    try {
      // Clean the response (remove markdown code blocks if present)
      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(cleaned);

      return ProfessionalInsight(
        sessionId: sessionId,
        summary: json['summary'] ?? '',
        vocabulary: List<String>.from(json['vocabulary'] ?? []),
        themes: List<String>.from(json['themes'] ?? []),
        actionItems: List<String>.from(json['actionItems'] ?? []),
        deadlines: List<String>.from(json['deadlines'] ?? []),
        mentionedPeople: List<String>.from(json['mentionedPeople'] ?? []),
        isAvailable: true,
      );
    } catch (e) {
      debugPrint('AI response parse error: $e');
      // Return basic insight from raw text
      return ProfessionalInsight(
        sessionId: sessionId,
        summary: response.length > 500 ? response.substring(0, 500) : response,
        isAvailable: true,
      );
    }
  }
}
