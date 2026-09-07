import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environmental stop does not publish OFF before native teardown', () {
    final dartSource = File('lib/main.dart').readAsStringSync();
    final nativeSource = File(
      'android/app/src/main/kotlin/com/humsukhan/humsukhan/EnvironmentalMonitoringService.kt',
    ).readAsStringSync();

    final stopIndex = dartSource.indexOf("if (call.method == 'stop')");
    expect(stopIndex, greaterThanOrEqualTo(0));
    final nextHandler = dartSource.indexOf("if (call.method == 'audioData')", stopIndex);
    expect(nextHandler, greaterThan(stopIndex));

    final stopBlock = dartSource.substring(stopIndex, nextHandler);
    expect(stopBlock, contains('detector.stopMonitoring();'));
    expect(stopBlock, isNot(contains("'state': 'OFF'")));
    expect(stopBlock, isNot(contains("pipelineState")));

    final cleanupIndex = nativeSource.indexOf('private fun cleanupAndStop()');
    expect(cleanupIndex, greaterThanOrEqualTo(0));
    final persistOffIndex = nativeSource.indexOf(
      'EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.OFF)',
      cleanupIndex,
    );
    expect(persistOffIndex, greaterThan(cleanupIndex));
    expect(nativeSource.lastIndexOf('stopNativeAudioCapture()', persistOffIndex), greaterThan(cleanupIndex));
    expect(nativeSource.indexOf('engine?.destroy()', cleanupIndex), greaterThan(cleanupIndex));
  });
}
