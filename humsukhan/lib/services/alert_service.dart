import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';

/// Central accessibility alert feedback: system notification, haptic, screen flash and flashlight.
///
/// Split by where it can run. [notify] needs no screen, so the environmental
/// monitoring isolate calls it for every alert, including while the app is
/// closed. [flash] draws over the app and drives the torch through the
/// activity, so it only runs while the app is on screen.
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

  /// System notification plus, if enabled, vibration.
  Future<void> notify({required String type, required String severity, required double confidence, required bool haptic}) async {
    await NotificationService.instance.showEnvironmentalAlert(type: type, severity: severity, confidence: confidence);
    if (haptic) await _triggerHaptic(severity);
  }

  /// In-app visual feedback: screen flash and camera flashlight.
  void flash(String severity, {required bool screen, required bool flashlight}) {
    if (screen) _triggerScreenFlash(severity);
    if (flashlight) unawaited(_triggerFlashlight(severity));
  }

  Future<void> _triggerHaptic(String severity) async {
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
    final context = _overlayContext;
    if (context == null || !context.mounted || _isFlashing) return;
    final flashColor = switch (severity) {
      'critical' => Colors.red.withValues(alpha: 0.6),
      'warning' => Colors.orange.withValues(alpha: 0.4),
      _ => Colors.blue.withValues(alpha: 0.3),
    };
    _isFlashing = true;
    _flashOverlay = OverlayEntry(builder: (_) => AnimatedOpacity(opacity: 1.0, duration: const Duration(milliseconds: 100), child: Container(color: flashColor)));
    Overlay.of(context).insert(_flashOverlay!);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 300), () {
      _flashOverlay?.remove();
      _flashOverlay = null;
      _isFlashing = false;
    });
  }

  Future<void> _triggerFlashlight(String severity) async {
    if (!Platform.isAndroid) return;
    try {
      if (!(await Permission.camera.status).isGranted) {
        debugPrint('Flashlight alert skipped: camera permission is not granted');
        return;
      }

      const channel = MethodChannel('com.humsukhan.flashlight');
      final available = await channel.invokeMethod<bool>('isAvailable') ?? false;
      if (!available) {
        debugPrint('Flashlight alert skipped: no available camera torch');
        return;
      }

      final flashCount = severity == 'critical' ? 4 : 2;
      for (int i = 0; i < flashCount; i++) {
        final turnedOn = await channel.invokeMethod<bool>('turnOn') ?? false;
        if (!turnedOn) return;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final turnedOff = await channel.invokeMethod<bool>('turnOff') ?? false;
        if (!turnedOff) return;
        if (i < flashCount - 1) await Future<void>.delayed(const Duration(milliseconds: 150));
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
    // cancel() is async: a failure arrives later, past any try/catch here.
    unawaited(Vibration.cancel().then<void>((_) {}, onError: (Object e) => debugPrint('Vibration cancel failed: $e')));
  }

  void dispose() => stopAll();
}
