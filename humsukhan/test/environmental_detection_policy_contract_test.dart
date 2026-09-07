import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doorbell and knock alerts do not require a second detection', () {
    final source = File('lib/services/sound_detection_service.dart').readAsStringSync();

    expect(source, contains("static const double _nonCriticalThreshold = 0.55;"));
    expect(source, contains("static const Duration cooldownDuration = Duration(seconds: 30);"));

    final processIndex = source.indexOf('void _processDetection(');
    expect(processIndex, greaterThanOrEqualTo(0));
    final emitIndex = source.indexOf('_emitEvent(eventType, confidence);', processIndex);
    expect(emitIndex, greaterThan(processIndex));

    final processingBlock = source.substring(processIndex, emitIndex + '_emitEvent(eventType, confidence);'.length);
    expect(processingBlock, isNot(contains('_passesTemporalConfirmation(eventType, now)')));
  });
}
