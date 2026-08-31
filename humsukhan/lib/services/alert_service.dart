import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';

/// Central accessibility alert feedback: system notification, haptic, screen flash and flashlight.
class AlertService {
  static final AlertService _instance = AlertService._();
  static AlertService get instance => _instance;
  AlertService._();

  BuildContext? _overlayContext;
  OverlayEntry? _flashOverlay;
  Timer? _flashTimer;
  bool _isFlashing = false;

  void registerContext(BuildContext context) {
    _overlayContext = context;
    unawaited(NotificationService.instance.initialize());
  }

  void triggerAlert(SettingsProvider settings, {String type = 'Environmental sound', double confidence = 0.0, String severity = 'warning'}) {
    unawaited(NotificationService.instance.showEnvironmentalAlert(type: type, severity: severity, confidence: confidence));
    if (settings.hapticAlerts) _triggerHaptic(severity);
    if (settings.screenFlashAlerts) _triggerScreenFlash(severity);
    if (settings.flashAlerts) _triggerFlashlight(severity);
  }

  void _triggerHaptic(String severity) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) return;
      switch (severity) {
        case 'critical':
          await Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200], intensities: [255, 0, 255, 0, 255]);
          break;
        case 'warning':
          await Vibration.vibrate(pattern: [0, 300, 150, 300], intensities: [200, 0, 200]);
          break;
        default:
          await Vibration.vibrate(duration: 150, amplitude: 128);
      }
    } catch (e) {
      debugPrint('Haptic alert failed: $e');
    }
  }

  void _triggerScreenFlash(String severity) {
    if (_overlayContext == null || _isFlashing) return;
    final flashColor = switch (severity) {
      'critical' => Colors.red.withValues(alpha: 0.6),
      'warning' => Colors.orange.withValues(alpha: 0.4),
      _ => Colors.blue.withValues(alpha: 0.3),
    };
    _isFlashing = true;
    _flashOverlay = OverlayEntry(builder: (_) => AnimatedOpacity(opacity: 1.0, duration: const Duration(milliseconds: 100), child: Container(color: flashColor)));
    Overlay.of(_overlayContext!).insert(_flashOverlay!);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 300), () {
      _flashOverlay?.remove();
      _flashOverlay = null;
      _isFlashing = false;
    });
  }

  void _triggerFlashlight(String severity) async {
    try {
      const channel = MethodChannel('com.humsukhan.flashlight');
      final flashCount = severity == 'critical' ? 4 : 2;
      for (int i = 0; i < flashCount; i++) {
        await channel.invokeMethod('turnOn');
        await Future.delayed(const Duration(milliseconds: 200));
        await channel.invokeMethod('turnOff');
        if (i < flashCount - 1) await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      debugPrint('Flashlight alert not available: $e');
    }
  }

  void stopAll() {
    _flashTimer?.cancel();
    _flashOverlay?.remove();
    _flashOverlay = null;
    _isFlashing = false;
    try { Vibration.cancel(); } catch (_) {}
  }

  void dispose() => stopAll();
}
