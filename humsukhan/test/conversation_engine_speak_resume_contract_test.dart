import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversational replay resumes listening after speaking', () {
    final source = File('lib/services/conversation_engine.dart').readAsStringSync();
    final speakIndex = source.indexOf('Future<void> _speakLastUtterance()');
    expect(speakIndex, greaterThanOrEqualTo(0));
    final bodyEnd = source.indexOf('\n  static String _joinTurn', speakIndex);
    expect(bodyEnd, greaterThan(speakIndex));
    final body = source.substring(speakIndex, bodyEnd);

    expect(body, contains('await speech.speak'));
    expect(body, contains("await speech.startListening(language: 'Auto')"));
    expect(body.indexOf("await speech.startListening(language: 'Auto')"), greaterThan(body.indexOf('await speech.speak')));
  });
}
