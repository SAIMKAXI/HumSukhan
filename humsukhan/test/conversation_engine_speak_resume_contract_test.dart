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

    expect(body, contains('if (speech.isListening) await _stopListening();'));
    expect(body, contains("await speech.speak(lastSpeakerCaption.text, language: lastSpeakerCaption.language);"));
    expect(body, contains("await speech.startListening(language: 'Auto')"));

    final speakCall = body.indexOf('await speech.speak');
    final resumeCall = body.indexOf("await speech.startListening(language: 'Auto')", speakCall);
    expect(resumeCall, greaterThan(speakCall));
  });
}
