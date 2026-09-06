import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsProvider contains persistence failures at the fire-and-forget boundary', () {
    final source = File('lib/providers/settings_provider.dart').readAsStringSync();
    expect(source, contains("debugPrint('Settings persistence error: $e')"));
  });
}
