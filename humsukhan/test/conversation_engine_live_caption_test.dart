import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';

class _FakeSpeech extends EverydaySpeechProvider {
  final StreamController<SpeechResultEvent> controller =
      StreamController<SpeechResultEvent>.broadcast();

  bool _listening = false;

  @override
  Stream<SpeechResultEvent> get onResult => controller.stream;

  @override
  bool get isListening => _listening;

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}

  @override
  Future<void> warmUpTts() async {}

  @override
  Future<void> startListening({String language = 'English'}) async {
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    _listening = false;
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {}

  void emit(String text, {required bool isFinal, String language = 'English'}) {
    controller.add(SpeechResultEvent(
      text: text,
      isFinal: isFinal,
      confidence: isFinal ? 0.95 : 0.75,
      language: language,
      isLive: true,
      mode: STTMode.platform,
    ));
  }

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }
}

Future<void> _settleCommands() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const audioChannels = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
  ];

  setUp(() {
    for (final name in audioChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  tearDown(() {
    for (final name in audioChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  group('ConversationEngine live captions', () {
    test('interim -> final -> next utterance creates two committed captions', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      addTearDown(() {
        engine.dispose();
        conversation.dispose();
        speech.dispose();
      });

      await engine.setPauseThreshold(const Duration(milliseconds: 900));
      engine.startListening();
      await _settleCommands();
      expect(engine.state, ConversationEngineState.listening);

      speech.emit('hello wor', isFinal: false);
      speech.emit('hello world', isFinal: false);
      speech.emit('hello world', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>['hello world'],
      );
      expect(speech.isListening, isTrue);

      speech.emit('how are', isFinal: false);
      speech.emit('how are you', isFinal: false);
      speech.emit('how are you', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>['hello world', 'how are you'],
      );
    });

    test('queued recognizer result during stop cannot mutate the caption being finalized', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      addTearDown(() {
        engine.dispose();
        conversation.dispose();
        speech.dispose();
      });

      await engine.setPauseThreshold(Duration.zero);
      engine.startListening();
      await _settleCommands();
      speech.emit('draft', isFinal: false);
      await _settleCommands();
      expect(engine.latestTranscript, 'draft');

      engine.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      speech.emit('draft should not replace', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>['draft'],
      );
      expect(conversation.currentPartial, isNull);
      expect(engine.state, ConversationEngineState.idle);
    });

    test('stop then restart starts with a clean live caption draft', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      addTearDown(() {
        engine.dispose();
        conversation.dispose();
        speech.dispose();
      });

      await engine.setPauseThreshold(const Duration(milliseconds: 900));
      engine.startListening();
      await _settleCommands();
      speech.emit('first turn', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      engine.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      engine.startListening();
      await _settleCommands();
      speech.emit('second turn', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        <String>['first turn', 'second turn'],
      );
    });
  });
}
