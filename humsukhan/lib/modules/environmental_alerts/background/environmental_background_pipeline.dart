import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../models/models.dart';
import '../services/android_service_monitor.dart';
import '../services/environmental_alert_pipeline.dart';
import '../services/sound_detection_engine.dart';

/// The Dart half of Android's monitoring service, run in the service's own
/// Flutter engine so it keeps working while the app is closed.
///
/// Protocol with `EnvironmentalMonitoringService`:
/// - Dart → native `pipelineState` `{state: READY}` once the model is loaded,
///   or `{state: ERROR, error: MODEL}`. Only after READY does native open the
///   microphone.
/// - native → Dart `audioData` with PCM16 bytes.
/// - Dart → native `pipelineState` `{state: PCM_FLOWING}` on the first audio
///   received. Native reports monitoring ACTIVE only then.
/// - Dart → native `event` `{event: <SoundEvent JSON>}` after an alert has
///   been recorded and announced, so an open app can show it.
/// - native → Dart `stop`.
Future<void> runEnvironmentalBackgroundPipeline({
  MethodChannel channel = const MethodChannel(AndroidServiceMonitor.methodChannelName),
  SoundDetectionEngine Function(void Function(SoundEvent) onDetected)? engine,
  EnvironmentalAlertPipeline? pipeline,
}) async {
  final alerts = pipeline ?? EnvironmentalAlertPipeline();
  final detector = (engine ?? (onDetected) => SoundDetectionEngine(onDetected: onDetected))((event) async {
    final announced = await alerts.handle(event);
    if (announced == null) return;
    try {
      await channel.invokeMethod('event', {'event': jsonEncode(announced.toJson())});
    } catch (e) {
      debugPrint('Environmental alert could not reach the service: $e');
    }
  });
  var audioConfirmed = false;

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'audioData':
        final bytes = call.arguments;
        if (bytes is! Uint8List || bytes.isEmpty) return false;
        detector.addPcm(bytes);
        if (!audioConfirmed && detector.isRunning) {
          audioConfirmed = true;
          await channel.invokeMethod('pipelineState', {'state': 'PCM_FLOWING'});
        }
        return true;
      case 'stop':
        detector.stop();
        return true;
    }
    return null;
  });

  final ready = await detector.start();
  await channel.invokeMethod(
    'pipelineState',
    ready ? {'state': 'READY'} : {'state': 'ERROR', 'error': 'MODEL'},
  );
}
