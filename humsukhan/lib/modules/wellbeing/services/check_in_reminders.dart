import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../services/notification_service.dart';
import '../../../utils/urdu_text.dart';

/// A time of day for a reminder, local time.
@immutable
class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  List<int> toJson() => [hour, minute];

  static ReminderTime? tryFromJson(Object? json) {
    if (json is! List || json.length != 2) return null;
    final [h, m] = json;
    if (h is! int || m is! int || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return ReminderTime(h, m);
  }

  @override
  bool operator ==(Object other) => other is ReminderTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}

/// When to remind the user to check in.
///
/// Reminders are scheduled as single notifications over the next
/// [horizon], not as one repeating alarm, so a slot the user has already
/// checked in for can be skipped. They are rescheduled each time HumSukhan
/// opens or a check-in is saved; if the app is not opened for [horizon],
/// reminders stop instead of nagging for ever.
class ReminderPlan {
  ReminderPlan._();

  static const Duration horizon = Duration(days: 14);

  /// A slot closer than this is skipped: it could already be in the past by
  /// the time it reaches the notification plugin, which refuses past times.
  static const Duration minimumLead = Duration(minutes: 1);

  /// The local times to remind at, oldest first. A slot is skipped when the
  /// user has already checked in since the previous slot on the same day
  /// (or since midnight, for the first slot of the day).
  static List<DateTime> slots({
    required List<ReminderTime> times,
    required DateTime now,
    DateTime? lastCheckIn,
    Duration within = horizon,
  }) {
    if (times.isEmpty) return const [];
    final ordered = {...times}.toList()..sort((a, b) => a.minutes.compareTo(b.minutes));
    final end = now.add(within);
    final result = <DateTime>[];
    for (var dayOffset = 0; ; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      if (day.isAfter(end)) break;
      DateTime? previous;
      for (final time in ordered) {
        final slot = DateTime(day.year, day.month, day.day, time.hour, time.minute);
        final windowStart = previous ?? day;
        previous = slot;
        if (!slot.isAfter(now.add(minimumLead)) || slot.isAfter(end)) continue;
        if (lastCheckIn != null && lastCheckIn.isAfter(windowStart) && !lastCheckIn.isAfter(slot)) continue;
        result.add(slot);
      }
    }
    return result;
  }
}

/// Shows the reminders. An interface so tests can run without the
/// notification plugin.
abstract class CheckInReminderScheduler {
  /// Replaces every scheduled reminder with one at each of [slots].
  Future<void> schedule(List<DateTime> slots, {required String title, required String body});

  Future<void> cancelAll();

  /// Asks for notification permission if needed. False when the user has
  /// notifications for HumSukhan switched off.
  Future<bool> ensurePermission();
}

/// [CheckInReminderScheduler] on top of `flutter_local_notifications`.
///
/// Needs `RECEIVE_BOOT_COMPLETED` and the plugin's two scheduled-notification
/// receivers in `AndroidManifest.xml`, so reminders survive a restart and an
/// app update. Uses inexact alarms: a reminder may arrive a few minutes late,
/// which needs no special alarm permission.
class LocalNotificationReminders implements CheckInReminderScheduler {
  LocalNotificationReminders({NotificationService? notifications})
      : _notifications = notifications ?? NotificationService.instance;

  final NotificationService _notifications;

  /// Reminder notification ids are [firstId] .. [firstId] + [maxReminders] - 1.
  static const int firstId = 7100;
  static const int maxReminders = 60;
  static const String channelId = 'wellbeing_checkins';

  /// Scheduling and cancelling run one at a time, app-wide, so two changes
  /// in quick succession cannot interleave and leave a mixed schedule.
  static Future<void> _queue = Future<void>.value();

  static Future<void> _serial(Future<void> Function() job) {
    final run = _queue.then((_) => job());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<void> schedule(List<DateTime> slots, {required String title, required String body}) =>
      _serial(() => _schedule(slots, title: title, body: body));

  Future<void> _schedule(List<DateTime> slots, {required String title, required String body}) async {
    await _cancelAll();
    final plugin = await _notifications.plugin();
    if (plugin == null) throw StateError('Notifications are not available on this device.');
    // The channel is named in the reminder's own language.
    final urdu = containsUrduScript(title);
    final android = AndroidNotificationDetails(
      channelId,
      urdu ? 'ذہنی سکون کے چیک اِن' : 'Wellbeing check-ins',
      channelDescription: urdu ? 'ایک نرم روزانہ یاد دہانی کہ آپ کیسا محسوس کر رہے ہیں۔' : 'A gentle daily reminder to check in with how you feel.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );
    const apple = DarwinNotificationDetails(presentAlert: true, presentSound: false, presentBadge: false);
    final details = NotificationDetails(android: android, iOS: apple, macOS: apple);
    for (var i = 0; i < slots.length && i < maxReminders; i++) {
      await plugin.zonedSchedule(
        id: firstId + i,
        title: title,
        body: body,
        // The exact moment, in UTC: the slot was worked out in local time,
        // so the device's time zone does not need to be known here.
        scheduledDate: tz.TZDateTime.from(slots[i], tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: NotificationService.checkInPayload,
      );
    }
  }

  @override
  Future<void> cancelAll() => _serial(_cancelAll);

  Future<void> _cancelAll() async {
    final plugin = await _notifications.plugin();
    if (plugin == null) return;
    for (var i = 0; i < maxReminders; i++) {
      await plugin.cancel(id: firstId + i);
    }
  }

  @override
  Future<bool> ensurePermission() => _notifications.ensurePermission();
}
