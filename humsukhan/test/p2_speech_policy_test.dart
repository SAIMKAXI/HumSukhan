import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/roman_urdu_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Roman Urdu detector recognizes a strong phrase', () {
    expect(RomanUrduDetector.isRomanUrdu('Aap kaise hain'), isTrue);
    expect(RomanUrduDetector.isRomanUrdu('This is a meeting'), isFalse);
  });

  test('Everyday text routing promotes Roman Urdu to Urdu processing', () {
    final provider = EverydaySpeechProvider();
    addTearDown(provider.dispose);

    // Roman Urdu is normalized to Urdu script before rendering/TTS, so the
    // downstream processing language is Urdu rather than a separate voice.
    expect(
      provider.processingLanguageForText('Aap kaise hain', fallback: 'English'),
      'Urdu',
    );
    expect(
      provider.processingLanguageForText('Please start the meeting', fallback: 'English'),
      'English',
    );
    expect(
      provider.processingLanguageForText('آپ کیسے ہیں؟', fallback: 'English'),
      'Urdu',
    );
  });
}
