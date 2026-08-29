import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class ProfessionalProvider extends ChangeNotifier {
  List<ProfessionalSession> _sessions = [];
  List<Folder> _folders = [];
  List<ProfessionalInsight> _insights = [];
  ProfessionalSession? _activeSession;
  bool _isLoading = false;

  // Getters
  List<ProfessionalSession> get sessions => List.unmodifiable(_sessions);
  List<Folder> get folders => List.unmodifiable(_folders);
  List<ProfessionalInsight> get insights => List.unmodifiable(_insights);
  ProfessionalSession? get activeSession => _activeSession;
  bool get isLoading => _isLoading;

  List<ProfessionalSession> get recentSessions {
    final completed = _sessions.where((s) => s.status == SessionStatus.completed).toList();
    completed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return completed.take(5).toList();
  }

  List<ProfessionalSession> getSessionsForFolder(String? folderId) {
    return _sessions.where((s) => s.folderId == folderId).toList();
  }

  ProfessionalInsight? getInsightForSession(String sessionId) {
    try {
      return _insights.firstWhere((i) => i.sessionId == sessionId);
    } catch (_) {
      return null;
    }
  }

  ProfessionalProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load sessions
      final sessionsJson = prefs.getString('professionalSessions') ?? '[]';
      _sessions = (jsonDecode(sessionsJson) as List)
          .map((s) => ProfessionalSession.fromJson(s))
          .toList();

      // Load folders
      final foldersJson = prefs.getString('professionalFolders') ?? '[]';
      _folders = (jsonDecode(foldersJson) as List)
          .map((f) => Folder.fromJson(f))
          .toList();

      // Load insights
      final insightsJson = prefs.getString('professionalInsights') ?? '[]';
      _insights = (jsonDecode(insightsJson) as List)
          .map((i) => ProfessionalInsight.fromJson(i))
          .toList();

      // Clean expired sessions
      _cleanExpiredSessions();
    } catch (e) {
      debugPrint('Error loading professional data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('professionalSessions', jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('professionalFolders', jsonEncode(_folders.map((f) => f.toJson()).toList()));
  }

  Future<void> _saveInsights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('professionalInsights', jsonEncode(_insights.map((i) => i.toJson()).toList()));
  }

  void _cleanExpiredSessions() {
    final before = _sessions.length;
    _sessions.removeWhere((s) => s.isExpired);
    if (_sessions.length != before) {
      _saveSessions();
    }
  }

  // Session management
  Future<ProfessionalSession> createSession({
    required String title,
    required SessionType type,
    String? folderId,
    String captionLanguage = 'English',
    int retentionDays = 7,
  }) async {
    // Enforce hard 15-day maximum retention
    final enforcedRetentionDays = retentionDays.clamp(1, 15);
    final session = ProfessionalSession(
      title: title,
      type: type,
      folderId: folderId,
      captionLanguage: captionLanguage,
      retentionDays: enforcedRetentionDays,
    );
    _sessions.add(session);
    _activeSession = session;
    await _saveSessions();

    // Sync to Supabase
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertSession(session);
    }

    notifyListeners();
    return session;
  }

  void startSessionRecording(String sessionId) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _activeSession = _sessions[idx].copyWith(status: SessionStatus.inProgress);
      _sessions[idx] = _activeSession!;
      _saveSessions();
      notifyListeners();
    }
  }

  Future<void> stopSession(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      final session = _sessions[idx];
      final transcript = session.captions.map((c) => '${c.speaker}: ${c.text}').join('\n');
      _sessions[idx] = session.copyWith(
        status: SessionStatus.completed,
        transcriptText: transcript,
      );
      _activeSession = null;
      await _saveSessions();

      // Sync to Supabase
      if (SupabaseService.instance.isAuthenticated) {
        await DatabaseService.instance.upsertSession(_sessions[idx]);
      }

      notifyListeners();
    }
  }

  void addCaptionToSession(String sessionId, Caption caption) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      final session = _sessions[idx];
      final updatedCaptions = List<Caption>.from(session.captions)..add(caption);
      _sessions[idx] = session.copyWith(captions: updatedCaptions);
      _saveSessions();
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _insights.removeWhere((i) => i.sessionId == sessionId);
    await _saveSessions();
    await _saveInsights();

    // Delete from Supabase
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.deleteSession(sessionId);
    }

    notifyListeners();
  }

  // Folder management
  Future<Folder> createFolder(String name) async {
    final folder = Folder(name: name);
    _folders.add(folder);
    await _saveFolders();
    notifyListeners();
    return folder;
  }

  Future<void> deleteFolder(String folderId) async {
    // Move sessions to general (no folder)
    for (var i = 0; i < _sessions.length; i++) {
      if (_sessions[i].folderId == folderId) {
        _sessions[i] = _sessions[i].copyWith(folderId: null);
      }
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _saveFolders();
    await _saveSessions();
    notifyListeners();
  }

  Future<void> moveSessionToFolder(String sessionId, String? folderId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _sessions[idx] = _sessions[idx].copyWith(folderId: folderId);
      await _saveSessions();
      notifyListeners();
    }
  }

  // AI Insights — uses real AI (Gemini Flash) when available, local extraction as fallback
  Future<void> generateInsights(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    final existingIdx = _insights.indexWhere((i) => i.sessionId == sessionId);

    final allText = session.captions.map((c) => c.text).join('\n');
    if (allText.trim().isEmpty) return;

    // Try real AI first
    ProfessionalInsight? aiInsight;
    if (AiService.instance.isAvailable) {
      aiInsight = await AiService.instance.generateInsights(
        sessionId: sessionId,
        transcript: allText,
        sessionTitle: session.title,
        sessionType: session.type,
      );
    }

    // Fall back to local extraction if AI unavailable
    final insight = aiInsight ?? _generateLocalInsights(session, allText);

    if (existingIdx != -1) {
      _insights[existingIdx] = insight;
    } else {
      _insights.add(insight);
    }
    await _saveInsights();

    // Sync to Supabase
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertInsight(insight);
    }

    notifyListeners();
  }

  /// Local keyword extraction fallback when AI is unavailable.
  ProfessionalInsight _generateLocalInsights(ProfessionalSession session, String allText) {
    final allSpeakers = session.captions.map((c) => c.speaker).toSet().toList();
    return ProfessionalInsight(
      sessionId: session.id,
      summary: _buildSummary(session, allText),
      vocabulary: _extractVocabulary(allText),
      themes: _extractThemes(allText, session.title),
      actionItems: _extractActionItems(allText),
      deadlines: _extractDeadlines(allText),
      mentionedPeople: allSpeakers.where((s) => s != 'Speaker 1').toList(),
      isAvailable: session.captions.isNotEmpty,
    );
  }

  List<String> _extractVocabulary(String text) {
    if (text.isEmpty) return [];
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toList();

    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }

    // Filter stop words and get top terms
    final stopWords = {
      'this', 'that', 'with', 'from', 'have', 'will', 'been', 'were',
      'they', 'their', 'them', 'than', 'then', 'also', 'what', 'when',
      'your', 'just', 'some', 'more', 'very', 'like', 'each', 'much',
      'about', 'would', 'could', 'should', 'there', 'these', 'those',
      'into', 'over', 'only', 'other', 'such', 'after', 'well', 'know',
    };

    final sorted = freq.entries
        .where((e) => !stopWords.contains(e.key) && e.value >= 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(8).map((e) => e.key).toList();
  }

  List<String> _extractThemes(String text, String title) {
    if (text.isEmpty) return [title];
    final themes = <String>[];
    themes.add(title);

    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 10).toList();
    final themeKeywords = {
      'planning': 'Planning & Scheduling',
      'testing': 'Quality Assurance',
      'design': 'Design & Architecture',
      'review': 'Review & Feedback',
      'deploy': 'Deployment',
      'launch': 'Product Launch',
      'meeting': 'Collaboration',
      'discuss': 'Discussion',
      'deadline': 'Timeline Management',
      'team': 'Team Coordination',
      'feature': 'Feature Development',
      'bug': 'Issue Resolution',
      'requirement': 'Requirements',
      'feedback': 'Feedback',
    };

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      for (final entry in themeKeywords.entries) {
        if (lower.contains(entry.key) && !themes.contains(entry.value)) {
          themes.add(entry.value);
        }
      }
    }

    return themes.take(5).toList();
  }

  List<String> _extractActionItems(String text) {
    if (text.isEmpty) return [];
    final actions = <String>[];
    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 5).toList();

    final actionPatterns = [
      RegExp(r'\b(need to|must|should|will|going to|plan to|have to)\b', caseSensitive: false),
      RegExp(r'\b(complete|prepare|review|finish|send|update|create|build|fix|check)\b', caseSensitive: false),
    ];

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;
      for (final pattern in actionPatterns) {
        if (pattern.hasMatch(trimmed) && actions.length < 5) {
          final cleaned = trimmed[0].toUpperCase() + trimmed.substring(1);
          if (!actions.contains(cleaned)) {
            actions.add(cleaned);
          }
          break;
        }
      }
    }

    return actions;
  }

  List<String> _extractDeadlines(String text) {
    if (text.isEmpty) return [];
    final deadlines = <String>[];
    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 5).toList();

    final datePatterns = [
      RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}', caseSensitive: false),
      RegExp(r'\b(\d{1,2}/\d{1,2}/\d{2,4})'),
      RegExp(r'\b(next week|this week|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      RegExp(r'\b(by\s+\w+\s+\d{1,2})', caseSensitive: false),
    ];

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(trimmed);
        if (match != null && deadlines.length < 5) {
          final cleaned = trimmed[0].toUpperCase() + trimmed.substring(1);
          if (!deadlines.any((d) => d.toLowerCase() == cleaned.toLowerCase())) {
            deadlines.add(cleaned);
          }
          break;
        }
      }
    }

    return deadlines;
  }

  String _buildSummary(ProfessionalSession session, String allText) {
    if (allText.isEmpty) {
      return 'No content was captured in this session.';
    }

    final captionCount = session.captions.length;
    final sentences = allText.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 10).toList();
    final keySentences = sentences.take(3).join('. ');

    return 'This ${session.type.name} session ("${session.title}") contained '
        '$captionCount captions. $keySentences.';
  }

  // Retention check
  void checkRetention() {
    _cleanExpiredSessions();
    notifyListeners();
  }

  // Set a demo session with captions
  void addDemoSession() {
    final session = ProfessionalSession(
      title: 'Product Launch Planning',
      type: SessionType.meeting,
      captionLanguage: 'English',
      retentionDays: 7,
      status: SessionStatus.completed,
      captions: [
        Caption(text: 'Welcome everyone to the product launch planning meeting.', speaker: 'Speaker 1'),
        Caption(text: 'We need to finalize the testing timeline by next week.', speaker: 'Speaker 2'),
        Caption(text: 'I will prepare the launch documentation by September 10th.', speaker: 'Speaker 1'),
        Caption(text: 'Great, let\'s also review the deployment checklist together.', speaker: 'Speaker 2'),
      ],
    );
    _sessions.add(session);
    _saveSessions();
    notifyListeners();
  }
}
