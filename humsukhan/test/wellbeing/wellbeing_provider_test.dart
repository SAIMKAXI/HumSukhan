import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/wellbeing/models/mood_entry.dart';
import 'package:humsukhan/modules/wellbeing/services/check_in_reminders.dart';
import 'package:humsukhan/modules/wellbeing/services/mood_patterns.dart';
import 'package:humsukhan/modules/wellbeing/services/mood_store.dart';
import 'package:humsukhan/providers/wellbeing_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminders implements CheckInReminderScheduler {
  bool permission = true;
  bool fail = false;
  List<DateTime> scheduled = [];
  String title = '';
  int cancels = 0;

  @override
  Future<void> schedule(List<DateTime> slots, {required String title, required String body}) async {
    if (fail) throw StateError('no alarms');
    scheduled = slots;
    this.title = title;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = [];
  }

  @override
  Future<bool> ensurePermission() async => permission;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reminder plan', () {
    const evening = [ReminderTime(20, 0)];
    const twice = [ReminderTime(10, 0), ReminderTime(20, 0)];

    test('once a day, every day for two weeks', () {
      final slots = ReminderPlan.slots(times: evening, now: DateTime(2026, 10, 28, 9));
      expect(slots.first, DateTime(2026, 10, 28, 20));
      expect(slots, hasLength(14));
      expect(slots.every((s) => s.hour == 20 && s.minute == 0), isTrue);
    });

    test('a time already passed today starts tomorrow', () {
      final slots = ReminderPlan.slots(times: evening, now: DateTime(2026, 10, 28, 21));
      expect(slots.first, DateTime(2026, 10, 29, 20));
    });

    test('checking in earlier today skips today\'s reminder', () {
      final slots = ReminderPlan.slots(
        times: evening,
        now: DateTime(2026, 10, 28, 15),
        lastCheckIn: DateTime(2026, 10, 28, 14),
      );
      expect(slots.first, DateTime(2026, 10, 29, 20));
    });

    test('a check-in late yesterday does not skip today', () {
      final slots = ReminderPlan.slots(
        times: evening,
        now: DateTime(2026, 10, 28, 9),
        lastCheckIn: DateTime(2026, 10, 27, 22),
      );
      expect(slots.first, DateTime(2026, 10, 28, 20));
    });

    test('twice a day, a check-in covers only the reminder that follows it', () {
      final slots = ReminderPlan.slots(
        times: twice,
        now: DateTime(2026, 10, 28, 12),
        lastCheckIn: DateTime(2026, 10, 28, 11),
      );
      // 11:00 is after the 10:00 reminder, so it stands in for 20:00.
      expect(slots.first, DateTime(2026, 10, 29, 10));
      expect(slots[1], DateTime(2026, 10, 29, 20));
    });

    test('a slot less than a minute away is left for tomorrow', () {
      final slots = ReminderPlan.slots(times: evening, now: DateTime(2026, 10, 28, 19, 59, 30));
      expect(slots.first, DateTime(2026, 10, 29, 20));
    });

    test('times given out of order are sorted, duplicates dropped', () {
      final slots = ReminderPlan.slots(
        times: const [ReminderTime(20, 0), ReminderTime(10, 0), ReminderTime(20, 0)],
        now: DateTime(2026, 10, 28, 0, 30),
      );
      expect(slots.take(2), [DateTime(2026, 10, 28, 10), DateTime(2026, 10, 28, 20)]);
    });
  });

  group('Wellbeing provider', () {
    late Directory dir;
    late FakeReminders reminders;
    var now = DateTime(2026, 10, 28, 9);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('wellbeing_provider');
      reminders = FakeReminders();
      now = DateTime(2026, 10, 28, 9);
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    WellbeingProvider make({String account = 'user-1'}) => WellbeingProvider(
          account: account,
          store: MoodStore(account: account, baseDirectory: () async => dir),
          reminders: reminders,
          clock: () => now,
        );

    test('a check-in is saved on the phone and survives a restart', () async {
      final provider = make();
      await provider.load();
      await provider.addCheckIn(Mood.low, tags: {MoodTag.tired}, note: '  long day  ');
      expect(provider.pattern.state, MoodState.lowDay);

      final reopened = make();
      await reopened.load();
      expect(reopened.entries, hasLength(1));
      expect(reopened.entries.single.note, 'long day');
      expect(reopened.entries.single.tags, {MoodTag.tired});
    });

    test('reminders are off until the user turns them on', () async {
      final provider = make();
      await provider.load();
      expect(provider.remindersOn, isFalse);
      expect(reminders.scheduled, isEmpty);

      expect(await provider.setRemindersOn(true), isNull);
      expect(reminders.scheduled.first, DateTime(2026, 10, 28, 20));
    });

    test('refused notification permission is reported and leaves reminders off', () async {
      reminders.permission = false;
      final provider = make();
      await provider.load();
      expect(await provider.setRemindersOn(true), ReminderFailure.permissionDenied);
      expect(provider.remindersOn, isFalse);
      expect(provider.reminderError, 'permission');
    });

    test('a scheduling failure is reported, not swallowed', () async {
      reminders.fail = true;
      final provider = make();
      await provider.load();
      expect(await provider.setRemindersOn(true), ReminderFailure.schedulingFailed);
      expect(provider.reminderError, 'scheduling');
    });

    test('checking in skips that day\'s reminder', () async {
      final provider = make();
      await provider.load();
      await provider.setRemindersOn(true);
      now = DateTime(2026, 10, 28, 15);
      await provider.addCheckIn(Mood.good);
      expect(reminders.scheduled.first, DateTime(2026, 10, 29, 20));
    });

    test('twice a day keeps the chosen time and adds the other half of the day', () async {
      final provider = make();
      await provider.load();
      await provider.setRemindersOn(true);
      await provider.setReminderTime(0, const ReminderTime(21, 30));
      await provider.setTwiceDaily(true);
      expect(provider.reminderTimes, const [ReminderTime(10, 0), ReminderTime(21, 30)]);
      await provider.setTwiceDaily(false);
      expect(provider.reminderTimes, const [ReminderTime(21, 30)]);
    });

    test('reminder choices are per account; another account clears this one\'s reminders', () async {
      final first = make(account: 'user-1');
      await first.load();
      await first.setRemindersOn(true);
      expect(reminders.scheduled, isNotEmpty);
      first.dispose();

      final second = make(account: 'user-2');
      await second.load();
      expect(second.remindersOn, isFalse);
      expect(reminders.scheduled, isEmpty);
      expect(second.entries, isEmpty);
    });

    test('reminder text follows the app language', () async {
      final provider = make();
      await provider.load();
      await provider.setRemindersOn(true);
      expect(reminders.title, 'How are you feeling today?');
      await provider.setUrdu(true);
      expect(reminders.title, 'آج آپ کیسا محسوس کر رہے ہیں؟');
    });

    test('deleting removes every check-in', () async {
      final provider = make();
      await provider.load();
      await provider.addCheckIn(Mood.good);
      await provider.addCheckIn(Mood.okay);
      await provider.deleteEntry(provider.entries.first.id);
      expect(provider.entries, hasLength(1));
      await provider.deleteAllCheckIns();
      expect(provider.entries, isEmpty);
      final reopened = make();
      await reopened.load();
      expect(reopened.entries, isEmpty);
    });
  });
}
