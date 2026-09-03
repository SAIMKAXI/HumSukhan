import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/speech_provider.dart';
import 'package:humsukhan/services/everyday_language_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Devanagari is removed before caption or language routing', () {
    const blocked = '\u092f\u0939 \u0926\u0947\u0935\u0928\u093e\u0917\u0930\u0940';
    final cleaned = EverydayLanguagePolicy.sanitizeHindi(blocked);

    expect(cleaned, isEmpty);
    expect(EverydayLanguagePolicy.languageForText(blocked), 'English');
  });

  test('mixed English and blocked script keeps only supported text', () {
    const input = 'Hello \u092f\u0939 world';
    final cleaned = EverydayLanguagePolicy.sanitizeHindi(input);

    expect(cleaned, 'Hello world');
    expect(EverydayLanguagePolicy.containsHindiScript(cleaned), isFalse);
  });

  test('shared SpeechProvider never routes blocked script to a separate language', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    const blocked = '\u092f\u0939 \u0938\u0948';
    expect(speech.processingLanguageForText(blocked), 'English');

    speech.detectLanguage(blocked);
    expect(speech.detectedLanguage?.language, 'English');
  });
}
