import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConversationEngine guards lifecycle callbacks after disposal', () {
    final source = File('lib/services/conversation_engine.dart').readAsStringSync();

    expect(source, contains('bool _disposed = false;'));
    expect(source, contains('if (_disposed) return;'));
    expect(source, contains('void notifyListeners()'));
    expect(source, contains('_disposed = true;'));
    expect(source, contains('if (_disposed) return;\n      await command();'));
  });
}
