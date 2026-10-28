import 'package:flutter/foundation.dart';

import '../models/mood_entry.dart';
import 'crisis_words.dart';

/// What the recent check-ins suggest, from the user's own point of view. These
/// are prompts for support, never a diagnosis.
enum MoodState {
  /// No check-in yet, or none recently enough to say anything.
  noData,

  /// The most recent check-in is good or great, with no low signs.
  doingWell,

  /// Nothing stands out.
  steady,

  /// The most recent check-in was low.
  lowDay,

  /// Several low check-ins in a row, or a clear drop below the user's usual.
  severalLowDays,

  /// The most recent check-in was the lowest mood, or its note mentioned
  /// self-harm. Answered with the fixed help screen, never generated text.
  urgent,
}

/// One day on the trend chart.
@immutable
class MoodDay {
  const MoodDay(this.day, this.average, this.count);

  /// Midnight, local time.
  final DateTime day;

  /// Null on a day without check-ins.
  final double? average;
  final int count;
}

@immutable
class MoodPattern {
  const MoodPattern({
    required this.state,
    required this.latest,
    required this.recentAverage,
    required this.usualAverage,
    required this.streakDays,
  });

  final MoodState state;
  final MoodEntry? latest;

  /// Average of the last [MoodPatterns.recentWindow], or null with too few.
  final double? recentAverage;

  /// The user's usual level: the average of the
  /// [MoodPatterns.baselineWindow] before the recent window, or null with too
  /// few check-ins to say.
  final double? usualAverage;

  /// Consecutive days, up to today or yesterday, with at least one check-in.
  final int streakDays;
}

/// The rules agreed for HumSukhan's wellbeing check-ins. Every threshold is
/// here, so they can be reviewed and changed in one place.
class MoodPatterns {
  MoodPatterns._();

  /// A check-in older than this says nothing about how the user is now.
  static const Duration staleAfter = Duration(hours: 36);

  /// Scores at or below this count as low.
  static const int lowScore = 2;

  /// This many low check-ins in a row is "several low days"...
  static const int lowRunLength = 3;

  /// ...when all of them fall within this long.
  static const Duration lowRunWithin = Duration(days: 7);

  /// "Recent" for the drop rule.
  static const Duration recentWindow = Duration(days: 3);

  /// "Usual" for the drop rule: this long, before the recent window.
  static const Duration baselineWindow = Duration(days: 14);

  static const int minRecentCheckIns = 2;
  static const int minBaselineCheckIns = 5;

  /// A recent average this far below the usual one is a clear drop...
  static const double dropBy = 1.0;

  /// ...as long as the recent average is no higher than this, so a fall
  /// from "great" to "good" is not called hard days.
  static const double dropCeiling = 3.0;

  static MoodPattern analyse(List<MoodEntry> entries, {required DateTime now}) {
    final sorted = [...entries]..sort((a, b) => a.at.compareTo(b.at));
    final latest = sorted.isEmpty ? null : sorted.last;
    final recentStart = now.subtract(recentWindow);
    final baselineStart = recentStart.subtract(baselineWindow);
    final recent = [for (final e in sorted) if (e.at.isAfter(recentStart) && !e.at.isAfter(now)) e.mood.score];
    final baseline = [
      for (final e in sorted)
        if (e.at.isAfter(baselineStart) && !e.at.isAfter(recentStart)) e.mood.score,
    ];
    final recentAverage = recent.length >= minRecentCheckIns ? _average(recent) : null;
    final usualAverage = baseline.length >= minBaselineCheckIns ? _average(baseline) : null;

    final state = _state(sorted, latest, recentAverage, usualAverage, now);
    return MoodPattern(
      state: state,
      latest: latest,
      recentAverage: recentAverage,
      usualAverage: usualAverage,
      streakDays: _streak(sorted, now),
    );
  }

  /// Whether a single check-in, on its own, calls for the help screen.
  static bool isUrgent(MoodEntry entry) =>
      entry.mood == Mood.veryLow || CrisisWords.mentionsSelfHarm(entry.note);

  static MoodState _state(
    List<MoodEntry> sorted,
    MoodEntry? latest,
    double? recentAverage,
    double? usualAverage,
    DateTime now,
  ) {
    if (latest == null || now.difference(latest.at) > staleAfter) return MoodState.noData;
    if (isUrgent(latest)) return MoodState.urgent;

    final lastRun = sorted.length >= lowRunLength ? sorted.sublist(sorted.length - lowRunLength) : const <MoodEntry>[];
    final lowRun = lastRun.isNotEmpty &&
        now.difference(lastRun.first.at) <= lowRunWithin &&
        lastRun.every((e) => e.mood.score <= lowScore);
    final dropped = recentAverage != null &&
        usualAverage != null &&
        usualAverage - recentAverage >= dropBy &&
        recentAverage <= dropCeiling;
    if (lowRun || dropped) return MoodState.severalLowDays;

    if (latest.mood.score <= lowScore) return MoodState.lowDay;
    if (latest.mood.score >= Mood.good.score) return MoodState.doingWell;
    return MoodState.steady;
  }

  /// Daily averages for the [days] days ending today, oldest first.
  static List<MoodDay> daily(List<MoodEntry> entries, {required DateTime now, required int days}) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          final scores = [
            for (final e in entries)
              if (e.at.year == day.year && e.at.month == day.month && e.at.day == day.day) e.mood.score,
          ];
          return MoodDay(day, scores.isEmpty ? null : _average(scores), scores.length);
        }(),
    ];
  }

  static int _streak(List<MoodEntry> sorted, DateTime now) {
    final days = {for (final e in sorted) DateTime(e.at.year, e.at.month, e.at.day)};
    var day = DateTime(now.year, now.month, now.day);
    // A streak still counts until the end of the day after the last check-in.
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static double _average(List<int> scores) => scores.reduce((a, b) => a + b) / scores.length;
}
