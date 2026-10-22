import 'package:flutter/foundation.dart';

import '../../../models/models.dart';
import '../../../services/alert_service.dart';
import 'alert_history_store.dart';
import 'alert_preferences.dart';

/// What happens to a sound the detector reported: the user's per-sound
/// switch is honoured, it is written to history, and it is announced by
/// notification and vibration.
///
/// This runs wherever detection runs — the Android monitoring isolate, or the
/// app itself on iOS — so an alert is announced exactly once, whether or not
/// the app is open. The screen adds only what needs a screen: the banner,
/// screen flash and flashlight.
class EnvironmentalAlertPipeline {
  EnvironmentalAlertPipeline({
    AlertHistoryStore? history,
    Future<AlertPreferences> Function()? preferences,
    Future<void> Function(SoundEvent event, AlertPreferences preferences)? announce,
  })  : _history = history ?? AlertHistoryStore(),
        _preferences = preferences ?? AlertPreferences.read,
        _announce = announce ?? _announceWithAlertService;

  final AlertHistoryStore _history;
  final Future<AlertPreferences> Function() _preferences;
  final Future<void> Function(SoundEvent, AlertPreferences) _announce;
  Future<void> _queue = Future.value();

  /// Returns the event if it was announced, or null if the user has switched
  /// this sound off. Events are handled one at a time, in arrival order, so
  /// two alerts close together cannot overwrite each other's history entry.
  Future<SoundEvent?> handle(SoundEvent event) {
    final result = _queue.then((_) => _handle(event));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Settings or storage trouble never swallows an alert: unreadable
  /// settings mean the defaults, and a failed announcement is still recorded.
  Future<SoundEvent?> _handle(SoundEvent event) async {
    AlertPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (e) {
      debugPrint('Environmental alert settings unavailable, using defaults: $e');
      preferences = const AlertPreferences();
    }
    if (!preferences.allows(event.type)) return null;
    await _history.append(event);
    try {
      await _announce(event, preferences);
    } catch (e) {
      debugPrint('Environmental alert could not be announced: $e');
    }
    return event;
  }

  static Future<void> _announceWithAlertService(SoundEvent event, AlertPreferences preferences) =>
      AlertService.instance.notify(
        type: event.type,
        severity: event.severity,
        confidence: event.confidence,
        visual: preferences.visualAlerts,
        haptic: preferences.hapticAlerts,
      );
}
