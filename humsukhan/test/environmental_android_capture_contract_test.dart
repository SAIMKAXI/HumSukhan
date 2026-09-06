import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/sound_detection_service.dart';

Uint8List _pcmBytes(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('Android environmental service dispatches PCM to Flutter on main thread', () {
    final source = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringService.kt',
    ).readAsStringSync();
    expect(source, contains('AudioRecord('));
    expect(source, contains('MediaRecorder.AudioSource.MIC'));
    expect(source, contains('AudioFormat.ENCODING_PCM_16BIT'));
    expect(source, contains('mainHandler.post {'));
    expect(source, contains('channel?.invokeMethod("audioData", payload)'));

    final dispatchIndex = source.indexOf('channel?.invokeMethod("audioData", payload)');
    final mainPostIndex = source.lastIndexOf('mainHandler.post {', dispatchIndex);
    expect(mainPostIndex, greaterThanOrEqualTo(0));
    expect(mainPostIndex, lessThan(dispatchIndex));
  });

  test('Android environmental service has a real PCM-flow watchdog', () {
    final source = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringService.kt',
    ).readAsStringSync();
    expect(source, contains('PCM_FLOW_TIMEOUT_MS = 5000L'));
    expect(source, contains('bytesCaptured'));
    expect(source, contains('lastPcmReadAtMs'));
    expect(source, contains('dartPcmFlowing'));
    expect(source, contains('"PCM_FLOWING"'));
    expect(source, contains('EnvironmentalMonitoringState.ERROR'));
    expect(source, contains('stopNativeAudioCapture()'));
  });

  test('Quick Settings tile delegates to the same environmental state machine', () {
    final tile = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringTileService.kt',
    ).readAsStringSync();
    final state = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringState.kt',
    ).readAsStringSync();
    expect(tile, contains('EnvironmentalMonitoringState.requestStart(this)'));
    expect(tile, contains('EnvironmentalMonitoringState.requestStop(this)'));
    expect(state, contains('ACTION_START'));
    expect(state, contains('ACTION_STOP'));
  });

  test('environmental bridge clears stale native state and releases the mic for speech', () {
    final source = File('lib/services/environmental_monitoring_bridge.dart').readAsStringSync();
    expect(source, contains('releaseForForegroundSpeech()'));
    expect(source, contains('if (_state != \'OFF\')'));
    expect(source, contains('_requestStopAndWaitForOff()'));
    expect(source, contains("invokeMethod<String>('getState')"));
  });

  test('foreground speech explicitly releases environmental microphone capture', () {
    final source = File('lib/providers/everyday_speech_provider.dart').readAsStringSync();
    expect(source, contains('EnvironmentalMonitoringBridge'));
    expect(source, contains('releaseForForegroundSpeech()'));
    final releaseIndex = source.indexOf('releaseForForegroundSpeech()');
    final bilingualIndex = source.indexOf('_bilingual.start', releaseIndex);
    expect(releaseIndex, greaterThanOrEqualTo(0));
    expect(bilingualIndex, greaterThan(releaseIndex));
  });

  test('background environmental Dart entrypoint consumes external PCM and confirms flow', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("call.method == 'audioData'"));
    expect(source, contains('detector.processExternalAudio(raw)'));
    expect(source, contains('startExternalMonitoring'));
    expect(source, contains("'state': 'PCM_FLOWING'"));
    expect(source, isNot(contains('detector.startMonitoring(permissionAlreadyGranted: true)')));
  });

  test('external PCM reaches a 3-second window despite arbitrary callback sizes', () {
    final accumulator = PcmWindowAccumulator(windowSamples: 6, hopSamples: 2);
    final windows = <Float32List>[];

    accumulator.add(_pcmBytes([1, 2]), windows.add);
    accumulator.add(_pcmBytes([3]), windows.add);
    accumulator.add(_pcmBytes([4, 5, 6]), windows.add);

    expect(accumulator.totalSamples, 6);
    expect(accumulator.windowsEmitted, 1);
    expect(windows, hasLength(1));
    expect(windows.single.length, 6);
    expect(windows.single.first, closeTo(1 / 32768.0, 1e-9));
    expect(windows.single.last, closeTo(6 / 32768.0, 1e-9));

    accumulator.add(_pcmBytes([7, 8]), windows.add);
    expect(accumulator.totalSamples, 8);
    expect(accumulator.windowsEmitted, 2);
    expect(windows, hasLength(2));
    expect(windows[1].first, closeTo(3 / 32768.0, 1e-9));
    expect(windows[1].last, closeTo(8 / 32768.0, 1e-9));
  });
}
