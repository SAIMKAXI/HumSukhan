import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/speech_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() {
    Future<dynamic> audioPlayerHandler(MethodCall call) async {
      // audioplayers creates each AudioPlayer through the per-player channel.
      // The language-detection tests do not exercise real audio playback, so
      // the platform calls can safely be no-ops in the VM test environment.
      return null;
    }

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
