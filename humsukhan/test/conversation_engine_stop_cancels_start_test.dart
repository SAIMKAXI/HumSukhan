import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';

class _SlowStartSpeech extends EverydaySpeechProvider {
  final StreamController<SpeechResultEvent> controller =
      StreamController<SpeechResultEvent>.broadcast();
  bool _listening = false;
  int stopCalls = 0;

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
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
    _listening = false;
  }

  @override
  Future<void> speak(String text, {String language = 'English'}) async {}

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const audioChannels = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
  ];

  setUpAll(() {
    for (final name in audioChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  tearDownAll(() {
    for (final name in audioChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('stop request invalidates an in-flight microphone start', () async {
    final speech = _SlowStartSpeech();
    final conversation = ConversationProvider()..startConversation();
    final engine = ConversationEngine(
      speech: speech,
      conversation: conversation,
    );
    addTearDown(() {
      engine.dispose();
      conversation.dispose();
      speech.dispose();
    });

    engine.startListening();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(engine.state, ConversationEngineState.startingMic);

    engine.stopListening();
    expect(engine.state, ConversationEngineState.processingFinal);

    await Future<void>.delayed(const Duration(milliseconds: 130));

    expect(speech.stopCalls, 1);
    expect(speech.isListening, isFalse);
    expect(engine.state, ConversationEngineState.idle);
  });
}
