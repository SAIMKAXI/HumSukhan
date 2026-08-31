import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    try {
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
    }
  }

  Future<void> showEnvironmentalAlert({
    required String type,
    required String severity,
    required double confidence,
  }) async {
    await initialize();
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
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails, macOS: iosDetails);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _plugin.show(
      id,
      '$type detected',
      '${(confidence * 100).round()}% confidence${severity == 'critical' ? ' — urgent' : ''}',
      details,
    );
  }
}
