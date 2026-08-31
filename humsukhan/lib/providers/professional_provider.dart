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
  Future<void> _persistQueue = Future.value();

  List<ProfessionalSession> get sessions => List.unmodifiable(_sessions);
  List<Folder> get folders => List.unmodifiable(_folders);
  List<ProfessionalInsight> get insights => List.unmodifiable(_insights);
  ProfessionalSession? get activeSession => _activeSession;
  bool get isLoading => _isLoading;

  List<ProfessionalSession> get recentSessions {
    final completed = _sessions.where((s) => s.status == SessionStatus.completed).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return completed.take(5).toList();
  }

  List<ProfessionalSession> getSessionsForFolder(String? folderId) =>
      _sessions.where((s) => s.folderId == folderId).toList();

  ProfessionalInsight? getInsightForSession(String sessionId) {
    for (final insight in _insights) {
      if (insight.sessionId == sessionId) return insight;
    }
    return null;
  }

  ProfessionalProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessions = (jsonDecode(prefs.getString('professionalSessions') ?? '[]') as List)
          .map((s) => ProfessionalSession.fromJson(s))
          .toList();
      _folders = (jsonDecode(prefs.getString('professionalFolders') ?? '[]') as List)
          .map((f) => Folder.fromJson(f))
          .toList();
      _insights = (jsonDecode(prefs.getString('professionalInsights') ?? '[]') as List)
          .map((i) => ProfessionalInsight.fromJson(i))
          .toList();
      if (SupabaseService.instance.isAuthenticated) await _syncFromCloud();
      await _cleanExpiredSessions();
    } catch (e) {
      debugPrint('Error loading professional data: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncFromCloud() async {
    try {
      final cloudSessions = await DatabaseService.instance.fetchSessions();
      final localIds = _sessions.map((s) => s.id).toSet();
      for (final cs in cloudSessions) {
        if (!localIds.contains(cs.id)) {
          _sessions.add(cs);
        } else {
          final idx = _sessions.indexWhere((s) => s.id == cs.id);
          if (idx != -1) {
            _sessions[idx] = cs;
          }
        }
      }
      await _saveSessions();

      final cloudFolders = await DatabaseService.instance.fetchFolders();
      final localFolderIds = _folders.map((f) => f.id).toSet();
      for (final cf in cloudFolders) {
        if (!localFolderIds.contains(cf.id)) _folders.add(cf);
      }
      await _saveFolders();
    } catch (e) {
      debugPrint('Cloud sync error: $e');
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'professionalSessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'professionalFolders',
      jsonEncode(_folders.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> _saveInsights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'professionalInsights',
      jsonEncode(_insights.map((i) => i.toJson()).toList()),
    );
  }

  Future<void> _cleanExpiredSessions() async {
    final before = _sessions.length;
    _sessions.removeWhere((s) => s.isExpired);
    if (_sessions.length != before) await _saveSessions();
  }

  Future<ProfessionalSession> createSession({
    required String title,
    required SessionType type,
    String? folderId,
    String captionLanguage = 'English',
    int retentionDays = 7,
  }) async {
    final session = ProfessionalSession(
      title: title,
      type: type,
      folderId: folderId,
      captionLanguage: captionLanguage,
      retentionDays: retentionDays.clamp(1, 15),
    );
    _sessions.add(session);
    _activeSession = session;
    await _saveSessions();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertSession(session);
    }
    notifyListeners();
    return session;
  }

  Future<void> startSessionRecording(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    _activeSession = _sessions[idx].copyWith(status: SessionStatus.inProgress);
    _sessions[idx] = _activeSession!;
    await _saveSessions();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertSession(_activeSession!);
    }
    notifyListeners();
  }

  Future<void> stopSession(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;

    // Wait for every caption persistence operation queued while recording.
    await _persistQueue;

    final session = _sessions[idx];
    final sortedCaptions = List<Caption>.from(session.captions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final completed = session.copyWith(
      status: SessionStatus.completed,
      captions: sortedCaptions,
      transcriptText:
          sortedCaptions.map((c) => '${c.speaker}: ${c.text}').join('\n'),
    );
    _sessions[idx] = completed;
    _activeSession = null;
    await _saveSessions();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertSession(completed);
    }
    notifyListeners();
  }

  Future<void> addCaptionToSession(String sessionId, Caption caption) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    if (_sessions[idx].captions.any((c) => c.id == caption.id)) return;

    final updated = List<Caption>.from(_sessions[idx].captions)
      ..add(caption)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final updatedSession = _sessions[idx].copyWith(
      captions: updated,
      transcriptText: updated.map((c) => '${c.speaker}: ${c.text}').join('\n'),
    );
    _sessions[idx] = updatedSession;
    notifyListeners();

    // Persist local and cloud copies in order so a later event can never
    // overwrite an earlier database write.
    _persistQueue = _persistQueue.then((_) async {
      await _saveSessions();
      if (SupabaseService.instance.isAuthenticated) {
        await DatabaseService.instance.upsertSession(updatedSession);
      }
    }).catchError((e) {
      debugPrint('Professional caption persistence error: $e');
    });

    await _persistQueue;
  }

  Future<void> deleteSession(String sessionId) async {
    await _persistQueue;
    _sessions.removeWhere((s) => s.id == sessionId);
    _insights.removeWhere((i) => i.sessionId == sessionId);
    await _saveSessions();
    await _saveInsights();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.deleteSession(sessionId);
    }
    notifyListeners();
  }

  Future<Folder> createFolder(String name) async {
    final folder = Folder(name: name.trim());
    _folders.add(folder);
    await _saveFolders();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertFolder(folder);
    }
    notifyListeners();
    return folder;
  }

  Future<void> deleteFolder(String folderId) async {
    await _persistQueue;
    for (var i = 0; i < _sessions.length; i++) {
      if (_sessions[i].folderId == folderId) {
        _sessions[i] = _sessions[i].copyWith(folderId: null);
        if (SupabaseService.instance.isAuthenticated) {
          await DatabaseService.instance.upsertSession(_sessions[i]);
        }
      }
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _saveFolders();
    await _saveSessions();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.deleteFolder(folderId);
    }
    notifyListeners();
  }

  Future<void> moveSessionToFolder(String sessionId, String? folderId) async {
    if (folderId != null && !_folders.any((f) => f.id == folderId)) return;
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    _sessions[idx] = _sessions[idx].copyWith(folderId: folderId);
    await _saveSessions();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertSession(_sessions[idx]);
    }
    notifyListeners();
  }

  Future<void> generateInsights(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    final existingIdx = _insights.indexWhere((i) => i.sessionId == sessionId);
    final allText = session.captions.map((c) => c.text).join('\n');
    if (allText.trim().isEmpty) return;
    ProfessionalInsight? aiInsight;
    if (AiService.instance.isAvailable) {
      aiInsight = await AiService.instance.generateInsights(
        sessionId: sessionId,
        transcript: allText,
        sessionTitle: session.title,
        sessionType: session.type,
      );
    }
    final insight = aiInsight ?? _generateLocalInsights(session, allText);
    if (existingIdx != -1) {
      _insights[existingIdx] = insight;
    } else {
      _insights.add(insight);
    }
    await _saveInsights();
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertInsight(insight);
    }
    notifyListeners();
  }

  ProfessionalInsight _generateLocalInsights(
    ProfessionalSession session,
    String allText,
  ) {
    final speakers = session.captions
        .map((c) => c.speaker)
        .toSet()
        .where((s) => s != 'Speaker 1')
        .toList();
    return ProfessionalInsight(
      sessionId: session.id,
      summary: _buildSummary(session, allText),
      vocabulary: _extractVocabulary(allText),
      themes: _extractThemes(allText, session.title),
      actionItems: _extractActionItems(allText),
      deadlines: _extractDeadlines(allText),
      mentionedPeople: speakers,
      isAvailable: session.captions.isNotEmpty,
    );
  }

  List<String> _extractVocabulary(String text) {
    if (text.isEmpty) return [];
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toList();
    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final stop = {
      'this','that','with','from','have','will','been','were','they','their','them','than','then','also','what','when','your','just','some','more','very','like','each','much','about','would','could','should','there','these','those','into','over','only','other','such','after','well','know'
    };
    final sorted = freq.entries.where((e) => !stop.contains(e.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  List<String> _extractThemes(String text, String title) {
    if (text.isEmpty) return [title];
    final themes = <String>[title];
    final keywords = {
      'planning':'Planning & Scheduling','testing':'Quality Assurance','design':'Design & Architecture','review':'Review & Feedback','deploy':'Deployment','launch':'Product Launch','meeting':'Collaboration','discuss':'Discussion','deadline':'Timeline Management','team':'Team Coordination','feature':'Feature Development','bug':'Issue Resolution','requirement':'Requirements','feedback':'Feedback'
    };
    for (final sentence in text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 10)) {
      final lower = sentence.toLowerCase();
      for (final e in keywords.entries) {
        if (lower.contains(e.key) && !themes.contains(e.value)) themes.add(e.value);
      }
    }
    return themes.take(5).toList();
  }

  List<String> _extractActionItems(String text) {
    if (text.isEmpty) return [];
    final actions = <String>[];
    final patterns = [
      RegExp(r'\b(need to|must|should|will|going to|plan to|have to)\b', caseSensitive: false),
      RegExp(r'\b(complete|prepare|review|finish|send|update|create|build|fix|check)\b', caseSensitive: false),
    ];
    for (final sentence in text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 5)) {
      final trimmed = sentence.trim();
      if (patterns.any((p) => p.hasMatch(trimmed)) && actions.length < 5) {
        final clean = '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
        if (!actions.contains(clean)) actions.add(clean);
      }
    }
    return actions;
  }

  List<String> _extractDeadlines(String text) {
    if (text.isEmpty) return [];
    final deadlines = <String>[];
    final patterns = [
      RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}', caseSensitive: false),
      RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'),
      RegExp(r'\b(next week|this week|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      RegExp(r'\bby\s+\w+\s+\d{1,2}\b', caseSensitive: false),
    ];
    for (final sentence in text.split(RegExp(r'[.!?]+')).where((s) => s.trim().length > 5)) {
      final trimmed = sentence.trim();
      if (patterns.any((p) => p.hasMatch(trimmed)) && deadlines.length < 5) {
        final clean = '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
        if (!deadlines.contains(clean)) deadlines.add(clean);
      }
    }
    return deadlines;
  }

  String _buildSummary(ProfessionalSession session, String allText) {
    if (allText.isEmpty) return 'No content was captured in this session.';
    final sentences = allText
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().length > 10)
        .take(3)
        .join('. ');
    return 'This ${session.type.name} session ("${session.title}") contained ${session.captions.length} captions. $sentences.';
  }

  void checkRetention() {
    _cleanExpiredSessions();
    notifyListeners();
  }

  void addDemoSession() {
    // Demo data is intentionally not injected into production sessions.
  }
}
