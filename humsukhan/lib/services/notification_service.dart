import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/environmental_alerts/models/environmental_sound.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;
  bool _launchPayloadTaken = false;
  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Payload of the wellbeing check-in reminder; tapping it opens the
  /// check-in.
  static const String checkInPayload = 'wellbeing.checkin';

  /// Payloads of notifications the user taps while HumSukhan is running.
  Stream<String> get taps => _taps.stream;

  /// The payload of the notification that started HumSukhan, once; null if
  /// the app was opened some other way.
  Future<String?> takeLaunchPayload() async {
    if (_launchPayloadTaken) return null;
    _launchPayloadTaken = true;
    await initialize(requestPermission: false);
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (e) {
      debugPrint('Notification launch details unavailable: $e');
      return null;
    }
  }

  /// The plugin, initialized; null when notifications cannot be used here.
  Future<FlutterLocalNotificationsPlugin?> plugin() async {
    await initialize(requestPermission: false);
    return _initialized ? _plugin : null;
  }

  /// Asks for notification permission (Android 13+) when it has not been
  /// granted, and reports whether notifications can be shown.
  Future<bool> ensurePermission() async {
    await initialize(requestPermission: false);
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        if (await android.areNotificationsEnabled() == true) return true;
        return await android.requestNotificationsPermission() == true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true) == true;
      return true;
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
      return false;
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) _taps.add(payload);
  }

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
        onDidReceiveNotificationResponse: _onResponse,
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
    // Alerts can be raised by the background monitor, outside any screen, so
    // the app language is read from the saved settings.
    final urdu = (await SharedPreferences.getInstance()).getString('appLanguage') == 'ur';
    final percent = (confidence * 100).round();
    final urgent = severity == 'critical';
    final importance = severity == 'critical' ? Importance.max : Importance.high;
    final priority = severity == 'critical' ? Priority.max : Priority.high;
    final androidDetails = AndroidNotificationDetails(
      'environmental_alerts',
      urdu ? 'ماحولیاتی الرٹس' : 'Environmental Alerts',
      channelDescription: urdu ? 'پہچانی گئی ماحولیاتی آوازیں اور رسائی کے الرٹس۔' : 'Detected environmental sounds and accessibility alerts.',
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
      title: urdu ? '${EnvironmentalSound.nameFor(type, urdu: true)} کی آواز پہچانی گئی' : '$type detected',
      body: urdu ? '$percent% اعتماد${urgent ? ' — فوری' : ''}' : '$percent% confidence${urgent ? ' — urgent' : ''}',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: appleDetails, macOS: appleDetails),
    );
  }
}
