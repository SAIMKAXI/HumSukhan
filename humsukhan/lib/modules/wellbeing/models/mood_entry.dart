import 'package:flutter/foundation.dart';

/// How the user said they feel, from 1 (very low) to 5 (great).
enum Mood {
  veryLow(1),
  low(2),
  okay(3),
  good(4),
  great(5);

  const Mood(this.score);
  final int score;

  static Mood fromScore(int score) =>
      Mood.values.firstWhere((m) => m.score == score, orElse: () => Mood.okay);

  /// A face that reads the same in any language and without reading at all.
  String get face => switch (this) {
        Mood.veryLow => '😞',
        Mood.low => '🙁',
        Mood.okay => '😐',
        Mood.good => '🙂',
        Mood.great => '😄',
      };
}

/// Optional words the user can add to a check-in. Stored by name, so the
/// order or wording on screen can change without changing saved data.
enum MoodTag {
  tired,
  lonely,
  leftOut,
  anxious,
  stressed,
  sad,
  calm,
  happy,
  grateful,
}

/// One check-in. Kept only on the phone (see `MoodStore`).
@immutable
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.at,
    required this.mood,
    this.tags = const {},
    this.note = '',
  });

  final String id;
  final DateTime at;
  final Mood mood;
  final Set<MoodTag> tags;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toUtc().toIso8601String(),
        'score': mood.score,
        'tags': [for (final tag in tags) tag.name],
        if (note.isNotEmpty) 'note': note,
      };

  /// Returns null for a record that cannot be read, so one damaged entry
  /// does not hide the others.
  static MoodEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    final score = json['score'];
    if (id is! String || id.isEmpty || at == null || score is! int || score < 1 || score > 5) {
      return null;
    }
    final rawTags = json['tags'];
    final tags = <MoodTag>{
      if (rawTags is List)
        for (final name in rawTags)
          for (final tag in MoodTag.values)
            if (tag.name == name) tag,
    };
    final note = json['note'];
    return MoodEntry(
      id: id,
      at: at.toLocal(),
      mood: Mood.fromScore(score),
      tags: tags,
      note: note is String ? note : '',
    );
  }
}
