import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/speech_provider.dart';

void main() {
  test('detectLanguage distinguishes Hindi script', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    speech.detectLanguage('यह हिंदी में एक वाक्य है');

    expect(speech.detectedLanguage?.language, 'Hindi');
    expect(speech.detectedLanguage?.script, 'Devanagari');
  });

  test('detectLanguage distinguishes Urdu script', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    speech.detectLanguage('یہ اردو میں ایک جملہ ہے');

    expect(speech.detectedLanguage?.language, 'Urdu');
    expect(speech.detectedLanguage?.script, 'Arabic');
  });

  test('detectLanguage distinguishes Roman Urdu and English', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    speech.detectLanguage('aap kya karna chahte hain');
    expect(speech.detectedLanguage?.language, 'Roman Urdu');

    speech.detectLanguage('this is an English sentence');
    expect(speech.detectedLanguage?.language, 'English');
  });
}
