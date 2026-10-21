import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The caption-language setter was retired with its control (see
  // settings_input_contract_test); only the app language is still settable.
  test('the app language setter validates against supported values', () {
    final source = File('lib/providers/settings_provider.dart').readAsStringSync();
    expect(source, contains("if (!const ['en', 'ur'].contains(langCode)) return;"));
  });
}
