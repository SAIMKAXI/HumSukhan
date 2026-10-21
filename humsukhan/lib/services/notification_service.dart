import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;

  /// [requestPermission] asks the user for notification permission on
  /// Android 13+. The environmental monitoring isolate has no activity to ask
  /// from, so it initializes without asking and relies on the app having
  /// asked when it was opened.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) {
      if (requestPermission) await _requestPermission();
      return;
    }
    const androidSettings = AndroidInitializationSettings('@drawable/humsukhan_logo');
    const appleSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: appleSettings,
          macOS: appleSettings,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
      return;
    }
    if (requestPermission) await _requestPermission();
  }

  Future<void> _requestPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> showEnvironmentalAlert({required String type, required String severity, required double confidence}) async {
    await initialize(requestPermission: false);
    if (!_initialized) return;
    final importance = severity == 'critical' ? Importance.max : Importance.high;
    final priority = severity == 'critical' ? Priority.max : Priority.high;
    final androidDetails = AndroidNotificationDetails(
      'environmental_alerts',
      'Environmental Alerts',
      channelDescription: 'Detected environmental sounds and accessibility alerts.',
      importance: importance,
      priority: priority,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
    );
    const appleDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: '$type detected',
      body: '${(confidence * 100).round()}% confidence${severity == 'critical' ? ' — urgent' : ''}',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: appleDetails, macOS: appleDetails),
    );
  }
}
