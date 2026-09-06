import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings language setters validate against supported values', () {
    final source = File('lib/providers/settings_provider.dart').readAsStringSync();
    expect(source, contains("if (!const ['English', 'Roman Urdu', 'Urdu'].contains(lang)) return;"));
    expect(source, contains("if (!const ['en', 'ur'].contains(langCode)) return;"));
  });
}
