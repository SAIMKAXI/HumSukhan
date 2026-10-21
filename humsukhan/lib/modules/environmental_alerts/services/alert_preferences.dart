import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The alert settings the detection pipeline needs, read from the keys
/// `SettingsProvider` persists.
///
/// The Android background isolate has no `SettingsProvider`, so both
/// platforms read the stored values; the app isolate's writes land there
/// first, so this is never staler than what the Settings screen shows.
class AlertPreferences {
  const AlertPreferences({
    this.allowedAlerts = const {},
    this.hapticAlerts = true,
    this.screenFlashAlerts = true,
    this.flashAlerts = false,
  });

  /// Missing entries mean allowed, matching `SettingsProvider`'s defaults.
  final Map<String, bool> allowedAlerts;
  final bool hapticAlerts;
  final bool screenFlashAlerts;
  final bool flashAlerts;

  bool allows(String type) => allowedAlerts[type] ?? true;

  static Future<AlertPreferences> read([Future<SharedPreferences> Function()? preferences]) async {
    final prefs = await (preferences ?? SharedPreferences.getInstance)();
    await prefs.reload();
    final allowed = <String, bool>{};
    try {
      final decoded = jsonDecode(prefs.getString('allowedAlerts') ?? '{}');
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is bool) allowed[entry.key as String] = entry.value as bool;
        }
      }
    } catch (e) {
      // Unreadable switches fall back to allowing every sound: a missed
      // siren is worse than an unwanted knock.
      debugPrint('Environmental alert switches could not be read: $e');
    }
    return AlertPreferences(
      allowedAlerts: allowed,
      hapticAlerts: prefs.getBool('hapticAlerts') ?? true,
      screenFlashAlerts: prefs.getBool('screenFlashAlerts') ?? true,
      flashAlerts: prefs.getBool('flashAlerts') ?? false,
    );
  }
}
