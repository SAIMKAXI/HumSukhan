import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monitoring startup never downloads the environmental model implicitly', () {
    final source = File('lib/providers/environmental_provider.dart').readAsStringSync();
    final prepareModelStart = source.indexOf('Future<bool> _prepareModel()');
    expect(prepareModelStart, greaterThanOrEqualTo(0));

    final nextMethod = source.indexOf('Future<void> toggleMonitoring()', prepareModelStart);
    final prepareModel = source.substring(prepareModelStart, nextMethod);

    expect(prepareModel, contains('_modelManager.initialize()'));
    expect(prepareModel, isNot(contains('downloadModel()')));
  });
}
