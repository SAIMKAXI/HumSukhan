import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Replaying a caption is the speaker button on each caption bubble, which
  // calls EverydaySpeechProvider.speak. That method owns pausing the
  // microphone (so the app never captions its own voice) and resuming the
  // same listening session afterwards.
  test('replaying a caption pauses listening and then resumes it', () {
    final source = File('lib/providers/everyday_speech_provider.dart').readAsStringSync();
    final speakIndex = source.indexOf('Future<void> speak(String text');
    expect(speakIndex, greaterThanOrEqualTo(0));
    final bodyEnd = source.indexOf('\n  Future<void> _speakEnglishMode', speakIndex);
    expect(bodyEnd, greaterThan(speakIndex));
    final body = source.substring(speakIndex, bodyEnd);

    final pause = body.indexOf('if (wasListening) await stopListening();');
    final tts = body.indexOf('_ttsProvider.speak', pause);
    final resume = body.indexOf('if (wasListening) await startListening(language: resumeLanguage);', tts);
    expect(pause, greaterThanOrEqualTo(0));
    expect(tts, greaterThan(pause));
    expect(resume, greaterThan(tts));
  });
}
