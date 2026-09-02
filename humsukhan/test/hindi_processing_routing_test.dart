import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/speech_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() {
    Future<dynamic> audioPlayerHandler(MethodCall call) async => null;

    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      audioPlayerHandler,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      audioPlayerHandler,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
  });

  tearDownAll(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
  });

  test('Devanagari keeps Hindi as an internal processing route', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    const hindi = 'यह हिंदी में एक वाक्य है';

    expect(speech.processingLanguageForText(hindi), 'Hindi');

    speech.detectLanguage(hindi);
    expect(speech.detectedLanguage?.language, 'English');
  });

  test('Urdu and Roman Urdu internal routing remains unchanged', () {
    final speech = SpeechProvider();
    addTearDown(speech.dispose);

    expect(speech.processingLanguageForText('یہ اردو ہے'), 'Urdu');
    expect(speech.processingLanguageForText('aap kya kar rahe hain'), 'Roman Urdu');
    expect(speech.processingLanguageForText('this is English'), 'English');
  });
}
