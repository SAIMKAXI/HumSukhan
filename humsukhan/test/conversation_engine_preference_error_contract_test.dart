import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConversationEngine does not silently swallow preference persistence errors', () {
    final source = File('lib/services/conversation_engine.dart').readAsStringSync();
    expect(source, isNot(contains('catch (_) {}')));
  });
}
