import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../providers/settings_provider.dart';

/// Service that handles alert feedback mechanisms:
/// - Haptic (vibration)
/// - Screen flash (overlay flash)
/// - Flashlight (camera torch)
///
/// Reads alert preferences from SettingsProvider.
class AlertService {
  static final AlertService _instance = AlertService._();
  static AlertService get instance => _instance;
  AlertService._();

  BuildContext? _overlayContext;
  OverlayEntry? _flashOverlay;
  Timer? _flashTimer;
  bool _isFlashing = false;

  /// Register the app's overlay context for screen flash effects.
  void registerContext(BuildContext context) {
    _overlayContext = context;
  }

  /// Trigger all enabled alert feedback mechanisms.
  /// Call this when a sound event is detected.
  void triggerAlert(SettingsProvider settings, {String severity = 'warning'}) {
    if (settings.hapticAlerts) {
      _triggerHaptic(severity);
    }
    if (settings.screenFlashAlerts) {
      _triggerScreenFlash(severity);
    }
    if (settings.flashAlerts) {
      _triggerFlashlight(severity);
    }
  }

  /// Trigger haptic feedback based on severity.
  void _triggerHaptic(String severity) async {
    try {
      bool hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) return;

      switch (severity) {
        case 'critical':
          // Urgent pattern: three short bursts
          await Vibration.vibrate(
            pattern: [0, 200, 100, 200, 100, 200],
            intensities: [255, 0, 255, 0, 255],
          );
          break;
        case 'warning':
          // Warning: double pulse
          await Vibration.vibrate(
            pattern: [0, 300, 150, 300],
            intensities: [200, 0, 200],
          );
          break;
        default:
          // Info: single short pulse
          await Vibration.vibrate(
            duration: 150,
            amplitude: 128,
          );
      }
    } catch (e) {
      debugPrint('Haptic alert failed: $e');
    }
  }

  /// Trigger a screen flash overlay effect.
  void _triggerScreenFlash(String severity) {
    if (_overlayContext == null) return;
    if (_isFlashing) return;

    Color flashColor;
    switch (severity) {
      case 'critical':
        flashColor = Colors.red.withValues(alpha: 0.6);
        break;
      case 'warning':
        flashColor = Colors.orange.withValues(alpha: 0.4);
        break;
      default:
        flashColor = Colors.blue.withValues(alpha: 0.3);
    }

    _isFlashing = true;
    _flashOverlay = OverlayEntry(
      builder: (context) => AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          color: flashColor,
        ),
      ),
    );

    Overlay.of(_overlayContext!).insert(_flashOverlay!);

    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 300), () {
      _flashOverlay?.remove();
      _flashOverlay = null;
      _isFlashing = false;
    });
  }

  /// Trigger the device flashlight (camera torch).
  /// Uses MethodChannel to access camera API for torch control.
  void _triggerFlashlight(String severity) async {
    try {
      const channel = MethodChannel('com.humsukhan.flashlight');

      // Flash pattern
      int flashCount = severity == 'critical' ? 4 : 2;
      int onDuration = 200;
      int offDuration = 150;

      for (int i = 0; i < flashCount; i++) {
        await channel.invokeMethod('turnOn');
        await Future.delayed(Duration(milliseconds: onDuration));
        await channel.invokeMethod('turnOff');
        if (i < flashCount - 1) {
          await Future.delayed(Duration(milliseconds: offDuration));
        }
      }
    } catch (e) {
      // Flashlight API not available on this device, silently ignore
      debugPrint('Flashlight alert not available: $e');
    }
  }

  /// Stop all active alerts.
  void stopAll() {
    _flashTimer?.cancel();
    _flashOverlay?.remove();
    _flashOverlay = null;
    _isFlashing = false;
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  void dispose() {
    stopAll();
  }
}
