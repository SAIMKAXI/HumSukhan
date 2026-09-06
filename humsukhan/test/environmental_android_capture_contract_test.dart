import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android environmental service captures PCM natively', () {
    final source = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringService.kt',
    ).readAsStringSync();
    expect(source, contains('AudioRecord('));
    expect(source, contains('MediaRecorder.AudioSource.MIC'));
    expect(source, contains('AudioFormat.ENCODING_PCM_16BIT'));
    expect(source, contains('invokeMethod("audioData"'));
  });

  test('background environmental Dart entrypoint consumes external PCM', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("call.method == 'audioData'"));
    expect(source, contains('detector.processExternalAudio(raw)'));
    expect(source, contains('startExternalMonitoring'));
    expect(source, isNot(contains('detector.startMonitoring(permissionAlreadyGranted: true)')));
  });
}
