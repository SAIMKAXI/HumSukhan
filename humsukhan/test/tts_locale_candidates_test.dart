import 'package:flutter_test/flutter_test.dart';

import 'package:humsukhan/services/speech_capability.dart';

void main() {
  test('English TTS candidates cover common regional engine locales', () {
    final candidates = SpeechCapability.instance.ttsCandidates('english');

    expect(candidates, containsAll(<String>[
      'en-US',
      'en-GB',
      'en-IN',
      'en-AU',
      'en-CA',
      'en-IE',
      'en-NZ',
      'en-SG',
      'en-ZA',
    ]));
  });

  test('Urdu TTS candidates include generic and regional locale forms', () {
    final candidates = SpeechCapability.instance.ttsCandidates('urdu');

    expect(candidates, containsAll(<String>[
      'ur',
      'ur-PK',
      'ur-IN',
    ]));
  });
}
