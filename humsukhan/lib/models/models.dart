import 'package:uuid/uuid.dart';
const _uuid = Uuid();

enum CaptionScript { latin, arabic, devanagari, other }

class CaptionSegment {
  final String text;
  final String language;
  final CaptionScript script;

  const CaptionSegment({
    required this.text,
    required this.language,
    required this.script,
  });

  bool get isRtl => script == CaptionScript.arabic;

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language,
        'script': script.name,
      };

  factory CaptionSegment.fromJson(Map<String, dynamic> json) {
    final rawScript = json['script']?.toString();
    CaptionScript script = CaptionScript.other;
    for (final value in CaptionScript.values) {
      if (value.name == rawScript) {
        script = value;
        break;
      }
    }
    if (script == CaptionScript.other &&
        json['language']?.toString().toLowerCase() == 'urdu') {
      script = CaptionScript.arabic;
    } else if (script == CaptionScript.other && rawScript == null) {
      script = CaptionScript.latin;
    }
    return CaptionSegment(
      text: json['text']?.toString() ?? '',
      language: json['language']?.toString() ?? 'English',
      script: script,
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String avatarEmoji;
  final String? avatarData;
  final String preferredLanguage;
  final String tutorName;
  final DateTime createdAt;

  UserProfile({String? id, this.name = 'User', this.avatarEmoji = '👤', this.avatarData, this.preferredLanguage = 'English', this.tutorName = 'Sam', DateTime? createdAt})
      : id = id ?? _uuid.v4(), createdAt = createdAt ?? DateTime.now();

  UserProfile copyWith({String? name, String? avatarEmoji, String? avatarData, String? preferredLanguage, String? tutorName}) => UserProfile(
        id: id,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarData: avatarData ?? this.avatarData,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        tutorName: tutorName ?? this.tutorName,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'avatarEmoji': avatarEmoji, 'avatarData': avatarData, 'preferredLanguage': preferredLanguage, 'tutorName': tutorName, 'createdAt': createdAt.toIso8601String()};
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(id: json['id'], name: json['name'] ?? 'User', avatarEmoji: json['avatarEmoji'] ?? '👤', avatarData: json['avatarData'], preferredLanguage: json['preferredLanguage'] ?? 'English', tutorName: json['tutorName'] ?? 'Sam', createdAt: DateTime.parse(json['createdAt']));
}

enum ConversationState { idle, starting, active, stopping, saveDecision }
enum SaveAction { deleteNow, save }

class Caption {
  final String id; final String text; final String speaker; final DateTime timestamp; final String language; final bool isPartial; final bool isOwn;
  final List<CaptionSegment> segments;
  Caption({String? id, required this.text, this.speaker = 'Speaker 1', DateTime? timestamp, this.language = 'English', this.isPartial = false, this.isOwn = false, List<CaptionSegment>? segments})
      : id = id ?? _uuid.v4(), timestamp = timestamp ?? DateTime.now(), segments = List.unmodifiable(segments ?? const []);
  Caption copyWith({String? text, bool? isPartial, String? speaker, String? language, List<CaptionSegment>? segments}) => Caption(id: id, text: text ?? this.text, speaker: speaker ?? this.speaker, timestamp: timestamp, language: language ?? this.language, isPartial: isPartial ?? this.isPartial, isOwn: isOwn, segments: segments ?? this.segments);
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'speaker': speaker, 'timestamp': timestamp.toIso8601String(), 'language': language, 'isPartial': isPartial, 'isOwn': isOwn, 'segments': segments.map((s) => s.toJson()).toList()};
  factory Caption.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    final segments = rawSegments is List
        ? rawSegments.whereType<Map>().map((item) => CaptionSegment.fromJson(Map<String, dynamic>.from(item))).where((s) => s.text.trim().isNotEmpty).toList()
        : <CaptionSegment>[];
    return Caption(id: json['id'], text: json['text'] ?? '', speaker: json['speaker'] ?? 'Speaker 1', timestamp: DateTime.parse(json['timestamp']), language: json['language'] ?? 'English', isPartial: json['isPartial'] ?? false, isOwn: json['isOwn'] ?? false, segments: segments);
  }
}

class QuickReply {
  final String id; final String text; final String category; final bool isFavorite; final DateTime createdAt;
  QuickReply({String? id, required this.text, this.category = 'General', this.isFavorite = false, DateTime? createdAt}) : id = id ?? _uuid.v4(), createdAt = createdAt ?? DateTime.now();
  QuickReply copyWith({String? text, String? category, bool? isFavorite}) => QuickReply(id: id, text: text ?? this.text, category: category ?? this.category, isFavorite: isFavorite ?? this.isFavorite, createdAt: createdAt);
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'category': category, 'isFavorite': isFavorite, 'createdAt': createdAt.toIso8601String()};
  factory QuickReply.fromJson(Map<String, dynamic> json) => QuickReply(id: json['id'], text: json['text'] ?? '', category: json['category'] ?? 'General', isFavorite: json['isFavorite'] ?? false, createdAt: DateTime.parse(json['createdAt']));
}

enum SessionType { meeting, lecture, class_ }
enum SessionStatus { inProgress, completed, archived }
class ProfessionalSession {
  final String id; final String title; final SessionType type; final String? folderId; final String captionLanguage; final int retentionDays; final DateTime createdAt; final DateTime expiresAt; final SessionStatus status; final List<Caption> captions; final String? transcriptText;
  ProfessionalSession({String? id, required this.title, this.type = SessionType.meeting, this.folderId, this.captionLanguage = 'English', int retentionDays = 7, DateTime? createdAt, DateTime? expiresAt, this.status = SessionStatus.inProgress, List<Caption>? captions, this.transcriptText}) : id = id ?? _uuid.v4(), retentionDays = retentionDays.clamp(1, RetentionPolicy.maxRetentionDays), createdAt = createdAt ?? DateTime.now(), expiresAt = expiresAt ?? (createdAt ?? DateTime.now()).add(Duration(days: retentionDays)), captions = captions ?? [];
  ProfessionalSession copyWith({String? title, SessionType? type, String? folderId, String? captionLanguage, int? retentionDays, SessionStatus? status, List<Caption>? captions, String? transcriptText, DateTime? expiresAt}) => ProfessionalSession(id: id, title: title ?? this.title, type: type ?? this.type, folderId: folderId ?? this.folderId, captionLanguage: captionLanguage ?? this.captionLanguage, retentionDays: retentionDays ?? this.retentionDays, createdAt: createdAt, expiresAt: expiresAt ?? this.expiresAt, status: status ?? this.status, captions: captions ?? this.captions, transcriptText: transcriptText ?? this.transcriptText);
  bool get isExpired => DateTime.now().isAfter(expiresAt); int get daysRemaining => expiresAt.difference(DateTime.now()).inDays;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type.index, 'folderId': folderId, 'captionLanguage': captionLanguage, 'retentionDays': retentionDays, 'createdAt': createdAt.toIso8601String(), 'expiresAt': expiresAt.toIso8601String(), 'status': status.index, 'captions': captions.map((c) => c.toJson()).toList(), 'transcriptText': transcriptText};
  factory ProfessionalSession.fromJson(Map<String, dynamic> json) => ProfessionalSession(id: json['id'], title: json['title'] ?? '', type: SessionType.values[json['type'] ?? 0], folderId: json['folderId'], captionLanguage: json['captionLanguage'] ?? 'English', retentionDays: json['retentionDays'] ?? 7, createdAt: DateTime.parse(json['createdAt']), expiresAt: DateTime.parse(json['expiresAt']), status: SessionStatus.values[json['status'] ?? 1], captions: (json['captions'] as List?)?.map((c) => Caption.fromJson(c)).toList() ?? [], transcriptText: json['transcriptText']);
}

class Folder {
  final String id; final String name; final DateTime createdAt;
  Folder({String? id, required this.name, DateTime? createdAt}) : id = id ?? _uuid.v4(), createdAt = createdAt ?? DateTime.now();
  Folder copyWith({String? name}) => Folder(id: id, name: name ?? this.name, createdAt: createdAt);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};
  factory Folder.fromJson(Map<String, dynamic> json) => Folder(id: json['id'], name: json['name'] ?? '', createdAt: DateTime.parse(json['createdAt']));
}

class ProfessionalInsight {
  final String id; final String sessionId; final String summary; final List<String> vocabulary; final List<String> themes; final List<String> actionItems; final List<String> deadlines; final List<String> mentionedPeople; final DateTime generatedAt; final bool isAvailable;
  ProfessionalInsight({String? id, required this.sessionId, this.summary = '', List<String>? vocabulary, List<String>? themes, List<String>? actionItems, List<String>? deadlines, List<String>? mentionedPeople, DateTime? generatedAt, this.isAvailable = false}) : id = id ?? _uuid.v4(), vocabulary = vocabulary ?? [], themes = themes ?? [], actionItems = actionItems ?? [], deadlines = deadlines ?? [], mentionedPeople = mentionedPeople ?? [], generatedAt = generatedAt ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'sessionId': sessionId, 'summary': summary, 'vocabulary': vocabulary, 'themes': themes, 'actionItems': actionItems, 'deadlines': deadlines, 'mentionedPeople': mentionedPeople, 'generatedAt': generatedAt.toIso8601String(), 'isAvailable': isAvailable};
  factory ProfessionalInsight.fromJson(Map<String, dynamic> json) => ProfessionalInsight(id: json['id'], sessionId: json['sessionId'], summary: json['summary'] ?? '', vocabulary: List<String>.from(json['vocabulary'] ?? []), themes: List<String>.from(json['themes'] ?? []), actionItems: List<String>.from(json['actionItems'] ?? []), deadlines: List<String>.from(json['deadlines'] ?? []), mentionedPeople: List<String>.from(json['mentionedPeople'] ?? []), generatedAt: DateTime.parse(json['generatedAt']), isAvailable: json['isAvailable'] ?? false);
}

class SoundEvent {
  final String id; final String type; final double confidence; final DateTime timestamp; final String severity; final bool dismissed;
  SoundEvent({String? id, required this.type, this.confidence = 0.8, DateTime? timestamp, this.severity = 'warning', this.dismissed = false}) : id = id ?? _uuid.v4(), timestamp = timestamp ?? DateTime.now();
  SoundEvent copyWith({bool? dismissed}) => SoundEvent(id: id, type: type, confidence: confidence, timestamp: timestamp, severity: severity, dismissed: dismissed ?? this.dismissed);
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'confidence': confidence, 'timestamp': timestamp.toIso8601String(), 'severity': severity, 'dismissed': dismissed};
  factory SoundEvent.fromJson(Map<String, dynamic> json) => SoundEvent(id: json['id'], type: json['type'] ?? 'Unknown', confidence: (json['confidence'] ?? 0.8).toDouble(), timestamp: DateTime.parse(json['timestamp']), severity: json['severity'] ?? 'warning', dismissed: json['dismissed'] ?? false);
}

class RetentionPolicy {
  final int days; final String label; const RetentionPolicy({required this.days, required this.label});
  static const options = [RetentionPolicy(days: 1, label: '1 day'), RetentionPolicy(days: 7, label: '7 days'), RetentionPolicy(days: 15, label: '15 days (maximum)')];
  static const maxRetentionDays = 15;
}

class LanguageResult { final String language; final double confidence; final String script; const LanguageResult({required this.language, required this.confidence, required this.script}); }
