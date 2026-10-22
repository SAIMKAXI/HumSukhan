import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../models/models.dart';
import '../models/monitoring_status.dart';
import 'android_service_monitor.dart';
import 'in_app_monitor.dart';

/// A change the screen should reflect: a new status, and/or a sound that has
/// just been announced.
@immutable
class MonitorUpdate {
  const MonitorUpdate(this.status, {this.failure, this.alert});

  final MonitoringStatus status;

  /// Set when [status] is [MonitoringStatus.error].
  final MonitoringFailure? failure;

  /// A sound that has already been written to history and announced.
  final SoundEvent? alert;
}

/// Owns the microphone for environmental monitoring on one platform.
///
/// Callers have already obtained microphone permission; a monitor reports a
/// missing grant as a failure rather than asking for one.
abstract class EnvironmentalMonitor {
  MonitoringStatus get status;
  MonitoringFailure? get failure;

  /// Broadcast stream of status changes and announced alerts.
  Stream<MonitorUpdate> get updates;

  /// Picks up monitoring that is already running, e.g. started from the
  /// Android Quick Settings tile before the app was opened.
  Future<void> attach();

  /// Completes once monitoring is active or has failed.
  Future<void> start();

  /// Completes once the microphone has been released, or stopping failed.
  Future<void> stop();

  /// Frees the microphone for foreground speech recognition. Returns false if
  /// monitoring is still holding it.
  Future<bool> releaseMicrophone() async {
    if (status.canStart) return true;
    await stop();
    final released = status.canStart;
    if (released) stoppedForSpeech = true;
    return released;
  }

  /// Monitoring was running and [releaseMicrophone] stopped it, so it should
  /// be started again once speech recognition is done with the microphone.
  bool stoppedForSpeech = false;
}

/// The monitor for this device. One per process, shared by the Alerts screen
/// and by foreground speech, which must be able to take the microphone back.
class EnvironmentalMonitoring {
  EnvironmentalMonitoring._();

  static EnvironmentalMonitor? _instance;

  static EnvironmentalMonitor get instance =>
      _instance ??= Platform.isAndroid ? AndroidServiceMonitor() : InAppMonitor();

  @visibleForTesting
  static set instance(EnvironmentalMonitor monitor) => _instance = monitor;

  /// Foreground speech and environmental monitoring cannot safely share the
  /// microphone, so speech releases it first.
  static Future<bool> releaseForForegroundSpeech() => instance.releaseMicrophone();

  /// Starts monitoring again if speech stopped it. Monitoring is the user's
  /// standing choice; captioning a conversation must not end it for good.
  static Future<void> resumeAfterForegroundSpeech() async {
    final monitor = instance;
    if (!monitor.stoppedForSpeech) return;
    monitor.stoppedForSpeech = false;
    if (monitor.status.canStart) await monitor.start();
  }
}
