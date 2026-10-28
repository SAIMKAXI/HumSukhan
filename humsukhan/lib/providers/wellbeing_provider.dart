import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../modules/wellbeing/models/mood_entry.dart';
import '../modules/wellbeing/services/check_in_reminders.dart';
import '../modules/wellbeing/services/mood_patterns.dart';
import '../modules/wellbeing/services/mood_store.dart';
import '../services/supabase_service.dart';

/// Why turning reminders on did not work.
enum ReminderFailure { permissionDenied, schedulingFailed }

/// Wellbeing check-ins for the signed-in account.
///
/// Check-ins live only on this phone ([MoodStore]); nothing here talks to
/// the server. Reminder and display choices are ordinary preferences, kept
/// per account so a shared phone does not mix two people's reminders.
class WellbeingProvider extends ChangeNotifier {
  WellbeingProvider({
    String? account,
    MoodStore? store,
    CheckInReminderScheduler? reminders,
    DateTime Function()? clock,
    bool autoLoad = true,
  })  : _account = account ?? _currentAccount(),
        _reminders = reminders ?? LocalNotificationReminders(),
        _clock = clock ?? DateTime.now {
    _store = store ?? MoodStore(account: _account);
    if (autoLoad) unawaited(load());
  }

  static String _currentAccount() {
    final id = SupabaseService.instance.userId;
    return id.isEmpty ? 'guest' : id;
  }

  static const List<ReminderTime> onceADay = [ReminderTime(20, 0)];
  static const List<ReminderTime> twiceADay = [ReminderTime(10, 0), ReminderTime(20, 0)];

  final String _account;
  late final MoodStore _store;
  final CheckInReminderScheduler _reminders;
  final DateTime Function() _clock;
  final Uuid _uuid = const Uuid();

  bool _loaded = false;
  bool _loadDamaged = false;
  bool _disposed = false;
  List<MoodEntry> _entries = const [];
  bool _remindersOn = false;
  List<ReminderTime> _reminderTimes = onceADay;
  bool _showBothLanguages = false;
  bool _introSeen = false;
  bool _urdu = false;
  String? _reminderError;
  Future<void>? _loading;

  bool get isLoaded => _loaded;

  /// Some saved check-ins could not be read and were set aside.
  bool get loadDamaged => _loadDamaged;

  /// Newest first.
  List<MoodEntry> get entries => _entries.reversed.toList(growable: false);
  MoodPattern get pattern => MoodPatterns.analyse(_entries, now: _clock());
  List<MoodDay> days(int count) => MoodPatterns.daily(_entries, now: _clock(), days: count);

  bool get remindersOn => _remindersOn;
  List<ReminderTime> get reminderTimes => List.unmodifiable(_reminderTimes);
  bool get twiceDaily => _reminderTimes.length > 1;
  bool get showBothLanguages => _showBothLanguages;
  bool get introSeen => _introSeen;

  /// Why the last attempt to schedule reminders failed, or null.
  String? get reminderError => _reminderError;

  String get _prefix => 'wellbeing:$_account';

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _introSeen = prefs.getBool('$_prefix:introSeen') ?? false;
      _showBothLanguages = prefs.getBool('$_prefix:showBoth') ?? false;
      final raw = prefs.getString('$_prefix:reminders');
      if (raw != null) {
        final json = jsonDecode(raw);
        if (json is Map) {
          _remindersOn = json['on'] == true;
          final times = [
            if (json['times'] is List)
              for (final t in json['times'] as List) ?ReminderTime.tryFromJson(t),
          ];
          if (times.isNotEmpty && times.length <= 2) _reminderTimes = times;
        }
      }
    } catch (e) {
      debugPrint('Wellbeing preferences could not be read: $e');
    }
    try {
      final loaded = await _store.load();
      _entries = loaded.entries;
      _loadDamaged = loaded.damaged;
    } catch (e) {
      debugPrint('Wellbeing check-ins could not be loaded: $e');
      _loadDamaged = true;
    }
    _loaded = true;
    _notify();
    // Bring the schedule up to date: another account may have left
    // reminders on this phone, and the two-week window moves on each open.
    await _syncReminders();
  }

  /// The app language changed; reminder text follows it.
  Future<void> setUrdu(bool urdu) async {
    if (_urdu == urdu) return;
    _urdu = urdu;
    if (_loaded && _remindersOn) await _syncReminders();
  }

  Future<void> markIntroSeen() async {
    _introSeen = true;
    _notify();
    await _setBool('introSeen', true);
  }

  Future<void> setShowBothLanguages(bool value) async {
    _showBothLanguages = value;
    _notify();
    await _setBool('showBoth', value);
  }

  /// Saves a check-in and returns it. Throws if it could not be saved, so the
  /// screen can say so instead of losing it quietly.
  Future<MoodEntry> addCheckIn(Mood mood, {Set<MoodTag> tags = const {}, String note = ''}) async {
    await load();
    final entry = MoodEntry(
      id: _uuid.v4(),
      at: _clock(),
      mood: mood,
      tags: Set.unmodifiable(tags),
      note: note.trim(),
    );
    final updated = [..._entries, entry];
    await _store.save(updated, now: _clock());
    _entries = updated;
    _notify();
    // Skip today's reminder now that the user has checked in.
    if (_remindersOn) await _syncReminders();
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final updated = [for (final e in _entries) if (e.id != id) e];
    await _store.save(updated, now: _clock());
    _entries = updated;
    _notify();
  }

  /// Deletes every check-in on this phone for this account.
  Future<void> deleteAllCheckIns() async {
    await _store.deleteAll();
    _entries = const [];
    _loadDamaged = false;
    _notify();
  }

  /// Returns null on success, or why reminders could not be turned on.
  Future<ReminderFailure?> setRemindersOn(bool on) async {
    await load();
    if (on && !await _reminders.ensurePermission()) {
      _remindersOn = false;
      _reminderError = 'permission';
      _notify();
      return ReminderFailure.permissionDenied;
    }
    _remindersOn = on;
    _notify();
    await _saveReminderPrefs();
    final ok = await _syncReminders();
    return ok ? null : ReminderFailure.schedulingFailed;
  }

  Future<bool> setTwiceDaily(bool twice) async {
    if (twice == twiceDaily) return true;
    // Keep the time the user already chose, and add the other half of the day.
    final kept = _reminderTimes.first;
    _reminderTimes = twice
        ? (kept.minutes < 12 * 60 ? [kept, twiceADay.last] : [twiceADay.first, kept])
        : [_reminderTimes.last];
    _notify();
    await _saveReminderPrefs();
    return _syncReminders();
  }

  Future<bool> setReminderTime(int index, ReminderTime time) async {
    if (index < 0 || index >= _reminderTimes.length) return false;
    final times = [..._reminderTimes]..[index] = time;
    _reminderTimes = times;
    _notify();
    await _saveReminderPrefs();
    return _syncReminders();
  }

  /// Schedules or cancels reminders to match the current choices. Returns
  /// false, and sets [reminderError], if scheduling failed.
  Future<bool> _syncReminders() async {
    // A provider for an account that has since signed out must not touch
    // the schedule the current account owns.
    if (_disposed) return true;
    try {
      if (!_remindersOn) {
        await _reminders.cancelAll();
      } else {
        final slots = ReminderPlan.slots(
          times: _reminderTimes,
          now: _clock(),
          lastCheckIn: _entries.isEmpty ? null : _entries.last.at,
        );
        await _reminders.schedule(
          slots,
          title: _urdu ? 'آج آپ کیسا محسوس کر رہے ہیں؟' : 'How are you feeling today?',
          body: _urdu ? 'چیک اِن کے لیے ٹیپ کریں۔ اس میں چند سیکنڈ لگتے ہیں۔' : 'Tap to check in. It takes a few seconds.',
        );
      }
      if (_reminderError != null) {
        _reminderError = null;
        _notify();
      }
      return true;
    } catch (e) {
      debugPrint('Wellbeing reminders could not be scheduled: $e');
      _reminderError = 'scheduling';
      _notify();
      return false;
    }
  }

  Future<void> _saveReminderPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix:reminders',
        jsonEncode({'on': _remindersOn, 'times': [for (final t in _reminderTimes) t.toJson()]}),
      );
    } catch (e) {
      debugPrint('Wellbeing reminder choice could not be saved: $e');
    }
  }

  Future<void> _setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix:$key', value);
    } catch (e) {
      debugPrint('Wellbeing preference $key could not be saved: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
