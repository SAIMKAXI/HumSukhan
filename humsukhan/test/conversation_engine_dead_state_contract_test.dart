import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConversationEngine no longer contains the retired write-only speechStarted state', () {
    final source = File('lib/services/conversation_engine.dart').readAsStringSync();
    expect(source, isNot(contains('_speechStarted')));
  });
}
