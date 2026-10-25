import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';

class _Speech extends EverydaySpeechProvider {
  final StreamController<SpeechResultEvent> controller = StreamController.broadcast();
  final StreamController<void> voice = StreamController.broadcast();
  final List<String> spoken = [];
  bool _listening = false;

  @override
  Stream<SpeechResultEvent> get onResult => controller.stream;
  @override
  Stream<void> get onSpeechStarted => voice.stream;
  @override
  bool get isListening => _listening;
  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}
  @override
  Future<void> warmUpTts() async {}
  @override
  Future<void> startListening({String language = 'English'}) async => _listening = true;
  @override
  Future<void> stopListening() async => _listening = false;

  /// Like the real provider: the microphone is off while the reply plays.
  @override
  Future<void> speak(String text, {String language = 'English'}) async {
    final was = _listening;
    _listening = false;
    spoken.add(text);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (was) _listening = true;
  }

  void say(String text, {bool isFinal = true}) => controller.add(SpeechResultEvent(
        text: text,
        isFinal: isFinal,
        confidence: 0.9,
        language: 'English',
        isLive: true,
        mode: STTMode.platform,
      ));
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late _Speech speech;
  late ConversationProvider conversation;
  late ConversationEngine engine;

  Future<void> listen({Duration pause = const Duration(milliseconds: 1000)}) async {
    speech = _Speech();
    conversation = ConversationProvider()..startConversation();
    engine = ConversationEngine(speech: speech, conversation: conversation);
    addTearDown(engine.dispose);
    await engine.setPauseThreshold(pause);
    engine.startListening();
    await _wait(20);
  }

  List<String> captions() => conversation.captions.map((c) => c.text).toList();

  group('Pauses inside a turn', () {
    test('a finished sentence becomes a caption sooner than the chosen pause', () async {
      await listen(pause: const Duration(milliseconds: 1700));
      speech.say('I am going home now.');
      await _wait(1000);
      expect(captions(), ['I am going home now.']);
    });

    test('stopping on "and" waits longer than the chosen pause', () async {
      await listen();
      speech.say('I wanted to tell you that');
      await _wait(1300);
      expect(captions(), isEmpty, reason: 'the speaker is still in the middle of the sentence');
      await _wait(700);
      expect(captions(), ['I wanted to tell you that']);
    });

    test('a hesitation carries the same sentence on', () async {
      await listen();
      speech.say('I was going to the.');
      await _wait(400);
      speech.say('market', isFinal: false);
      speech.say('market.');
      await _wait(1200);
      expect(captions(), ['I was going to the market.']);
    });

    test('a new sentence straight after a finished one stays in the caption, as a new sentence', () async {
      await listen();
      speech.say('I am fine.');
      await _wait(100);
      speech.say('how are you?');
      await _wait(1300);
      expect(captions(), ['I am fine. How are you?']);
    });

    test('a sound from the speaker during the pause keeps the caption open', () async {
      await listen();
      speech.say('maybe tomorrow');
      await _wait(700);
      speech.voice.add(null);
      await _wait(500);
      expect(captions(), isEmpty);
      await _wait(700);
      expect(captions(), ['maybe tomorrow']);
    });
  });

  group('Replying while the speaker talks', () {
    test('a typed reply keeps the microphone on and splits the captions', () async {
      await listen();
      speech.say('can you hear', isFinal: false);
      await _wait(10);
      engine.reply('Yes, clearly');
      await _wait(20);
      expect(speech.isListening, isTrue);
      expect(captions(), ['can you hear', 'Yes, clearly']);

      speech.say('Good.');
      await _wait(800);
      expect(captions(), ['can you hear', 'Yes, clearly', 'Good.']);
      expect(conversation.captions.last.isOwn, isFalse);
    });

    test('a spoken reply turns the microphone off while it plays, then listens again', () async {
      await listen();
      speech.say('what time is it', isFinal: false);
      await _wait(10);
      final speaking = engine.speakReply('Three o\'clock');
      await _wait(5);
      expect(engine.state, ConversationEngineState.speaking);
      expect(speech.isListening, isFalse);
      await speaking;
      await _wait(10);
      expect(speech.spoken, ['Three o\'clock']);
      expect(speech.isListening, isTrue);
      expect(engine.state, ConversationEngineState.listening);
      expect(captions(), ['what time is it']);
    });
  });

  group('Two recognizers on the same speech', () {
    String result(String transcript, double start, {double confidence = 0.9}) {
      final tokens = transcript.split(' ');
      return jsonEncode({
        'type': 'Results',
        'is_final': true,
        'speech_final': true,
        'channel': {
          'alternatives': [
            {
              'transcript': transcript,
              'confidence': confidence,
              'words': [
                for (var i = 0; i < tokens.length; i++)
                  {'word': tokens[i], 'punctuated_word': tokens[i], 'start': start + i * 0.3, 'end': start + i * 0.3 + 0.25, 'confidence': confidence},
              ],
            },
          ],
        },
      });
    }

    test('the slower one\'s copy of a finished sentence is not captioned again', () async {
      final stt = EverydayBilingualSttService.instance..debugBegin('Auto');
      final heard = <EverydayBilingualResult>[];
      final subscription = stt.onResult.listen(heard.add);
      addTearDown(subscription.cancel);

      stt.debugReceive('English', result('please send the report', 0));
      await _wait(250);
      stt.debugReceive('Urdu', result('پلیز سینڈ دی رپورٹ', 0, confidence: 0.5));
      await _wait(250);
      expect(heard.where((r) => r.isFinal).map((r) => r.text), ['please send the report']);

      stt.debugReceive('English', result('thank you', 2));
      await _wait(250);
      expect(heard.where((r) => r.isFinal).map((r) => r.text), ['please send the report', 'thank you']);
    });

    test('Urdu misheard as English words still shows as Urdu', () async {
      final stt = EverydayBilingualSttService.instance..debugBegin('Auto');
      final next = stt.onResult.firstWhere((r) => r.isFinal);
      stt.debugReceive('English', result('up key are not chart a hen', 0, confidence: 0.82));
      stt.debugReceive('Urdu', result('آپ کیا کرنا چاہتے ہیں', 0, confidence: 0.74));
      final heard = await next.timeout(const Duration(seconds: 2));
      expect(heard.text, 'آپ کیا کرنا چاہتے ہیں');
    });

    test('English spelled out in Urdu letters still shows as English', () async {
      final stt = EverydayBilingualSttService.instance..debugBegin('Auto');
      final next = stt.onResult.firstWhere((r) => r.isFinal);
      stt.debugReceive('English', result('the meeting starts at nine', 0, confidence: 0.78));
      stt.debugReceive('Urdu', result('دی میٹنگ سٹارٹس ایٹ نائن', 0, confidence: 0.86));
      final heard = await next.timeout(const Duration(seconds: 2));
      expect(heard.text, 'the meeting starts at nine');
    });

    test('a long silence from the recognizer ends the utterance even without an end-of-speech mark', () async {
      final stt = EverydayBilingualSttService.instance..debugBegin('Auto');
      final next = stt.onResult.firstWhere((r) => r.isFinal);
      final partial = jsonDecode(result('the train is late', 0)) as Map<String, dynamic>;
      partial['speech_final'] = false;
      stt.debugReceive('English', jsonEncode(partial));
      stt.debugReceive('English', jsonEncode({'type': 'UtteranceEnd', 'last_word_end': 1.2}));
      final heard = await next.timeout(const Duration(seconds: 2));
      expect(heard.text, 'the train is late');
    });
  });
}
