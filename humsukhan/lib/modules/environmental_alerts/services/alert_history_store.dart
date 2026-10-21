import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/models.dart';
import '../models/environmental_sound.dart';

/// Detected sounds, newest first, kept on the device only.
///
/// On Android alerts are recorded by the monitoring service's background
/// isolate while the screen reads and edits the same list from the app
/// isolate. Each isolate caches SharedPreferences separately, so every
/// operation reloads before it reads and writes the whole list straight
/// back, keeping the window in which the two can overlap as small as it can
/// be.
class AlertHistoryStore {
  AlertHistoryStore({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  static const storageKey = 'environmentalAlertHistory';
  static const maxEntries = 100;

  final Future<SharedPreferences> Function() _preferences;

  Future<List<SoundEvent>> load() async {
    try {
      final prefs = await _preferences();
      await prefs.reload();
      return _decode(prefs.getString(storageKey));
    } catch (e) {
      debugPrint('Environmental alert history could not be read: $e');
      return [];
    }
  }

  Future<List<SoundEvent>> append(SoundEvent event) =>
      _update((events) => [event, ...events]);

  Future<List<SoundEvent>> markDismissed(String id) => _update((events) => [
        for (final event in events) event.id == id ? event.copyWith(dismissed: true) : event,
      ]);

  Future<List<SoundEvent>> clear() => _update((_) => []);

  Future<List<SoundEvent>> _update(List<SoundEvent> Function(List<SoundEvent>) change) async {
    try {
      final prefs = await _preferences();
      await prefs.reload();
      final updated = change(_decode(prefs.getString(storageKey))).take(maxEntries).toList();
      await prefs.setString(storageKey, jsonEncode([for (final event in updated) event.toJson()]));
      return updated;
    } catch (e) {
      debugPrint('Environmental alert history could not be saved: $e');
      return load();
    }
  }

  List<SoundEvent> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final events = <SoundEvent>[];
      for (final item in decoded.whereType<Map>()) {
        try {
          final event = SoundEvent.fromJson(Map<String, dynamic>.from(item));
          // History from older builds can hold sounds that are no longer
          // detected; they would render without a description.
          if (EnvironmentalSound.byType(event.type) != null) events.add(event);
        } catch (e) {
          // One malformed entry must not cost the user the rest of history.
          debugPrint('Skipping unreadable environmental alert: $e');
        }
      }
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events;
    } catch (e) {
      debugPrint('Environmental alert history is unreadable: $e');
      return [];
    }
  }
}
