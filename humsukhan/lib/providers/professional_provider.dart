import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

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
    final session = ProfessionalSession(
      title: title,
      type: type,
      folderId: folderId,
      captionLanguage: captionLanguage,
      retentionDays: retentionDays,
    );
    _sessions.add(session);
    _activeSession = session;
    await _saveSessions();
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

  // AI Insights (mock)
  Future<void> generateInsights(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    final existingIdx = _insights.indexWhere((i) => i.sessionId == sessionId);

    // Mock AI insights
    final insight = ProfessionalInsight(
      sessionId: sessionId,
      summary: 'This ${session.type.name} session covered key topics related to "${session.title}". '
          'The discussion included actionable items and important deadlines that need attention.',
      vocabulary: ['accessibility', 'stakeholder', 'implementation', 'milestone'],
      themes: ['Project planning', 'Team coordination', 'Product development'],
      actionItems: ['Complete testing', 'Prepare documentation', 'Review deployment checklist'],
      deadlines: ['September 10 - Testing complete', 'September 15 - Launch preparation'],
      mentionedPeople: ['Speaker 1'],
      isAvailable: true,
    );

    if (existingIdx != -1) {
      _insights[existingIdx] = insight;
    } else {
      _insights.add(insight);
    }
    await _saveInsights();
    notifyListeners();
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
