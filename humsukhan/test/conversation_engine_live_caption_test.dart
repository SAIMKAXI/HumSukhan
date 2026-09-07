import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
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
  String? get lastStartError => null;

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

  void emit(String text, {bool isFinal = false, String language = 'English'}) {
    controller.add(SpeechResultEvent(
      text: text,
      isFinal: isFinal,
      confidence: 0.95,
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

  group('ConversationEngine live captions', () {
    test('interim -> final -> next utterance creates two committed captions', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      await engine.setPauseThreshold(const Duration(milliseconds: 40));

      engine.startListening();
      await _settleCommands();
      expect(engine.state, ConversationEngineState.listening);

      speech.emit('hello wor');
      speech.emit('hello world');
      speech.emit('hello world', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.single.text, 'hello world');
      expect(conversation.currentPartial, isNotNull);

      speech.emit('how are');
      speech.emit('how are you');
      speech.emit('how are you', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(conversation.captions, hasLength(2));
      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        ['hello world', 'how are you'],
      );

      engine.dispose();
      conversation.dispose();
      speech.dispose();
    });

    test('queued recognizer result during stop cannot mutate the caption being finalized', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      await engine.setPauseThreshold(Duration.zero);

      engine.startListening();
      await _settleCommands();
      speech.emit('draft');
      await _settleCommands();
      expect(engine.latestTranscript, 'draft');

      engine.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      speech.emit('draft should not replace');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(conversation.captions, hasLength(1));
      expect(conversation.captions.single.text, 'draft');
      expect(conversation.currentPartial, isNull);
      expect(engine.state, ConversationEngineState.idle);

      engine.dispose();
      conversation.dispose();
      speech.dispose();
    });

    test('a stopped conversation can restart listening without resurrecting stale text', () async {
      final speech = _FakeSpeech();
      final conversation = ConversationProvider();
      conversation.startConversation();
      final engine = ConversationEngine(
        speech: speech,
        conversation: conversation,
      );
      await engine.setPauseThreshold(const Duration(milliseconds: 40));

      engine.startListening();
      await _settleCommands();
      speech.emit('first turn', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      engine.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 70));

      engine.startListening();
      await _settleCommands();
      speech.emit('second turn', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(
        conversation.captions.map((caption) => caption.text).toList(),
        ['first turn', 'second turn'],
      );

      engine.dispose();
      conversation.dispose();
      speech.dispose();
    });
  });
}
