import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

enum FolderDeleteMode { keepSessions, deleteSessions }

class ProfessionalProvider extends ChangeNotifier {
  List<ProfessionalSession> _sessions = [];
  List<Folder> _folders = [];
  List<ProfessionalInsight> _insights = [];
  ProfessionalSession? _activeSession;
  bool _isLoading = false;
  Future<void> _persistQueue = Future.value();

  String get _storageSuffix { final userId = SupabaseService.instance.userId; return userId.isEmpty ? 'guest' : userId; }
  String get _sessionsKey => 'professionalSessions:$_storageSuffix';
  String get _foldersKey => 'professionalFolders:$_storageSuffix';
  String get _insightsKey => 'professionalInsights:$_storageSuffix';
  List<ProfessionalSession> get sessions => List.unmodifiable(_sessions);
  List<Folder> get folders => List.unmodifiable(_folders);
  List<ProfessionalInsight> get insights => List.unmodifiable(_insights);
  ProfessionalSession? get activeSession => _activeSession;
  bool get isLoading => _isLoading;
  List<ProfessionalSession> get recentSessions { final completed = _sessions.where((s) => s.status == SessionStatus.completed).toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt)); return completed.take(5).toList(); }
  List<ProfessionalSession> getSessionsForFolder(String? folderId) => _sessions.where((s)=>s.folderId==folderId).toList();
  ProfessionalInsight? getInsightForSession(String sessionId) { for (final i in _insights) { if (i.sessionId == sessionId) return i; } return null; }

  ProfessionalProvider() { _loadData(); }
  Future<void> _loadData() async {
    _isLoading = true; notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessions = (jsonDecode(prefs.getString(_sessionsKey) ?? '[]') as List).map((s)=>ProfessionalSession.fromJson(s)).toList();
      _folders = (jsonDecode(prefs.getString(_foldersKey) ?? '[]') as List).map((f)=>Folder.fromJson(f)).toList();
      _insights = (jsonDecode(prefs.getString(_insightsKey) ?? '[]') as List).map((i)=>ProfessionalInsight.fromJson(i)).toList();
      if (SupabaseService.instance.isAuthenticated) await _syncFromCloud();
      await _cleanExpiredSessions();
    } catch (e) { debugPrint('Error loading professional data: $e'); }
    _isLoading = false; notifyListeners();
  }
  Future<void> _syncFromCloud() async {
    try {
      final cloudSessions = await DatabaseService.instance.fetchSessions();
      for (final cs in cloudSessions) { final idx=_sessions.indexWhere((s)=>s.id==cs.id); if(idx==-1) _sessions.add(cs); else _sessions[idx]=cs; }
      await _saveSessions();
      final cloudFolders = await DatabaseService.instance.fetchFolders();
      final localFolderIds=_folders.map((f)=>f.id).toSet();
      for(final cf in cloudFolders) { if(!localFolderIds.contains(cf.id)) _folders.add(cf); }
      await _saveFolders();
      for (final session in _sessions) { final insight=await DatabaseService.instance.fetchInsight(session.id); if(insight!=null){ final idx=_insights.indexWhere((i)=>i.sessionId==session.id); if(idx==-1)_insights.add(insight);else _insights[idx]=insight; } }
      await _saveInsights();
    } catch(e){ debugPrint('Cloud sync error: $e'); }
  }
  Future<void> _saveSessions() async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_sessionsKey,jsonEncode(_sessions.map((s)=>s.toJson()).toList())); }
  Future<void> _saveFolders() async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_foldersKey,jsonEncode(_folders.map((f)=>f.toJson()).toList())); }
  Future<void> _saveInsights() async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_insightsKey,jsonEncode(_insights.map((i)=>i.toJson()).toList())); }
  Future<void> _cleanExpiredSessions() async { final before=_sessions.length; _sessions.removeWhere((s)=>s.isExpired); if(_sessions.length!=before) await _saveSessions(); }

  Future<ProfessionalSession> createSession({required String title, required SessionType type, String? folderId, String captionLanguage='English', int retentionDays=7}) async {
    final session=ProfessionalSession(title:title,type:type,folderId:folderId,captionLanguage:captionLanguage,retentionDays:retentionDays.clamp(1,15));
    _sessions.add(session); _activeSession=session; await _saveSessions(); if(SupabaseService.instance.isAuthenticated) await DatabaseService.instance.upsertSession(session); notifyListeners(); return session;
  }
  Future<void> startSessionRecording(String sessionId) async { final idx=_sessions.indexWhere((s)=>s.id==sessionId); if(idx==-1)return; _activeSession=_sessions[idx].copyWith(status:SessionStatus.inProgress); _sessions[idx]=_activeSession!; await _saveSessions(); if(SupabaseService.instance.isAuthenticated) await DatabaseService.instance.upsertSession(_activeSession!); notifyListeners(); }
  Future<void> stopSession(String sessionId) async { final idx=_sessions.indexWhere((s)=>s.id==sessionId); if(idx==-1)return; await _persistQueue; final session=_sessions[idx]; final sorted=List<Caption>.from(session.captions)..sort((a,b)=>a.timestamp.compareTo(b.timestamp)); final completed=session.copyWith(status:SessionStatus.completed,captions:sorted,transcriptText:sorted.map((c)=>'${c.speaker}: ${c.text}').join('\n')); _sessions[idx]=completed; _activeSession=null; await _saveSessions(); if(SupabaseService.instance.isAuthenticated)await DatabaseService.instance.upsertSession(completed); notifyListeners(); }
  Future<void> addCaptionToSession(String sessionId, Caption caption) async { final idx=_sessions.indexWhere((s)=>s.id==sessionId); if(idx==-1||_sessions[idx].captions.any((c)=>c.id==caption.id))return; final updated=List<Caption>.from(_sessions[idx].captions)..add(caption)..sort((a,b)=>a.timestamp.compareTo(b.timestamp)); final updatedSession=_sessions[idx].copyWith(captions:updated,transcriptText:updated.map((c)=>'${c.speaker}: ${c.text}').join('\n')); _sessions[idx]=updatedSession; notifyListeners(); _persistQueue=_persistQueue.then((_)async{await _saveSessions();if(SupabaseService.instance.isAuthenticated)await DatabaseService.instance.upsertSession(updatedSession);}).catchError((e){debugPrint('Professional caption persistence error: $e');}); await _persistQueue; }
  Future<void> deleteSession(String sessionId) async { await _persistQueue; _sessions.removeWhere((s)=>s.id==sessionId); _insights.removeWhere((i)=>i.sessionId==sessionId); await _saveSessions(); await _saveInsights(); if(SupabaseService.instance.isAuthenticated)await DatabaseService.instance.deleteSession(sessionId); notifyListeners(); }
  Future<Folder> createFolder(String name) async { final clean=name.trim(); if(clean.isEmpty) throw ArgumentError.value(name,'name','Folder name cannot be empty'); if(_folders.any((f)=>f.name.toLowerCase()==clean.toLowerCase())) throw ArgumentError.value(name,'name','A folder with this name already exists'); final folder=Folder(name:clean); _folders.add(folder); await _saveFolders(); if(SupabaseService.instance.isAuthenticated) await DatabaseService.instance.upsertFolder(folder); notifyListeners(); return folder; }

  Future<void> deleteFolder(String folderId, {FolderDeleteMode mode = FolderDeleteMode.keepSessions}) async {
    await _persistQueue;
    final folderExists = _folders.any((f) => f.id == folderId);
    if (!folderExists) return;
    final affected = _sessions.where((s) => s.folderId == folderId).toList();
    if (mode == FolderDeleteMode.keepSessions) {
      for (var i = 0; i < _sessions.length; i++) { if (_sessions[i].folderId == folderId) _sessions[i] = _sessions[i].copyWith(folderId: null); }
      if (SupabaseService.instance.isAuthenticated) await DatabaseService.instance.deleteFolder(folderId);
    } else {
      _sessions.removeWhere((s) => s.folderId == folderId);
      _insights.removeWhere((i) => affected.any((s) => s.id == i.sessionId));
      if (SupabaseService.instance.isAuthenticated) await DatabaseService.instance.deleteFolderAndSessions(folderId);
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _saveFolders();
    await _saveSessions();
    await _saveInsights();
    if (mode == FolderDeleteMode.keepSessions && SupabaseService.instance.isAuthenticated) { for (final s in affected) { await DatabaseService.instance.upsertSession(s.copyWith(folderId: null)); } }
    notifyListeners();
  }

  Future<void> moveSessionToFolder(String sessionId,String? folderId) async { if(folderId!=null&&!_folders.any((f)=>f.id==folderId))return; final idx=_sessions.indexWhere((s)=>s.id==sessionId);if(idx==-1)return;_sessions[idx]=_sessions[idx].copyWith(folderId:folderId);await _saveSessions();if(SupabaseService.instance.isAuthenticated)await DatabaseService.instance.upsertSession(_sessions[idx]);notifyListeners(); }

  Future<void> generateInsights(String sessionId) async {
    final session=_sessions.firstWhere((s)=>s.id==sessionId); final existingIdx=_insights.indexWhere((i)=>i.sessionId==sessionId); final allText=session.captions.map((c)=>c.text).join('\n'); if(allText.trim().isEmpty)return;
    final ai=AiService.instance.isAvailable ? await AiService.instance.generateInsights(sessionId:sessionId,transcript:allText,sessionTitle:session.title,sessionType:session.type) : null;
    final insight=ai ?? _generateLocalInsights(session,allText); if(existingIdx==-1)_insights.add(insight);else _insights[existingIdx]=insight; await _saveInsights(); if(SupabaseService.instance.isAuthenticated)await DatabaseService.instance.upsertInsight(insight); notifyListeners();
  }
  ProfessionalInsight _generateLocalInsights(ProfessionalSession session,String text){ final sentences=text.split(RegExp(r'[.!?]+')).map((s)=>s.trim()).where((s)=>s.length>10).toList(); final bullets=<String>[]; for(final sentence in sentences){if(bullets.length>=5)break; final clean='${sentence[0].toUpperCase()}${sentence.substring(1)}'; if(!bullets.contains(clean))bullets.add(clean);} if(bullets.isEmpty)bullets.add('Session captured ${session.captions.length} caption${session.captions.length==1?'':'s'}.'); final speakers=session.captions.map((c)=>c.speaker).toSet().where((s)=>s!='Speaker 1').toList(); return ProfessionalInsight(sessionId:session.id,summary:bullets.join(' '),summaryBullets:bullets,actionItems:_extractActionItems(text),deadlines:_extractDeadlines(text),mentionedPeople:speakers,isAvailable:true); }
  List<String> _extractActionItems(String text){final out=<String>[];final patterns=[RegExp(r'\b(need to|must|should|will|going to|plan to|have to)\b',caseSensitive:false),RegExp(r'\b(complete|prepare|review|finish|send|update|create|build|fix|check)\b',caseSensitive:false)];for(final sentence in text.split(RegExp(r'[.!?]+')).where((s)=>s.trim().length>5)){final t=sentence.trim();if(patterns.any((p)=>p.hasMatch(t))&&out.length<5){final c='${t[0].toUpperCase()}${t.substring(1)}';if(!out.contains(c))out.add(c);}}return out;}
  List<String> _extractDeadlines(String text){final out=<String>[];final patterns=[RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}',caseSensitive:false),RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'),RegExp(r'\b(next week|this week|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',caseSensitive:false)];for(final sentence in text.split(RegExp(r'[.!?]+')).where((s)=>s.trim().length>5)){final t=sentence.trim();if(patterns.any((p)=>p.hasMatch(t))&&out.length<5){final c='${t[0].toUpperCase()}${t.substring(1)}';if(!out.contains(c))out.add(c);}}return out;}
  void checkRetention(){_cleanExpiredSessions();notifyListeners();}
  void addDemoSession(){}
}
