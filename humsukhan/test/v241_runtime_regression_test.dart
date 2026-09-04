// Regression coverage for the v2.4.0 on-device bug report.
//
// Each group pins one defect that was observed on a real device and is now
// fixed, so the behaviour cannot silently regress again.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';
import 'package:humsukhan/theme/app_theme.dart';
import 'package:humsukhan/widgets/modern_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A speech provider whose recognition results the test drives by hand, so the
/// engine can be exercised without touching Deepgram, the microphone or TTS.
class _ScriptedSpeechProvider extends EverydaySpeechProvider {
  final StreamController<SpeechResultEvent> _scripted =
      StreamController<SpeechResultEvent>.broadcast();

  bool listening = false;
  bool warmedUp = false;

  @override
  Stream<SpeechResultEvent> get onResult => _scripted.stream;

  @override
  bool get isListening => listening;

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}

  @override
  Future<void> warmUpTts() async {
    warmedUp = true;
  }

  @override
  Future<void> startListening({String language = 'English'}) async {
    listening = true;
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }

  /// Pushes a recognition result through the same stream the engine listens to.
  void emit(String text, {required bool isFinal}) {
    _scripted.add(SpeechResultEvent(
      text: text,
      isFinal: isFinal,
      confidence: isFinal ? 0.9 : 0.6,
      language: 'English',
    ));
  }

  @override
  void dispose() {
    _scripted.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // EverydaySpeechProvider builds a real TTS/audio stack in its constructor.
  // These tests never play audio, so the platform channels are no-ops (same
  // approach as speech_language_detection_test.dart).
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

  group('Everyday continuous captions', () {
    test(
        'a pause commits the utterance and keeps listening, so the next '
        'utterance becomes its own caption', () async {
      final speech = _ScriptedSpeechProvider();
      final conversation = ConversationProvider();
      final engine = ConversationEngine(speech: speech, conversation: conversation);
      addTearDown(() {
        engine.dispose();
        conversation.dispose();
        speech.dispose();
      });

      conversation.startConversation();
      await engine.setPauseThreshold(const Duration(milliseconds: 900));
      engine.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(speech.isListening, isTrue);

      speech.emit('hello there', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((c) => c.text).toList(),
        <String>['hello there'],
      );
      expect(
        speech.isListening,
        isTrue,
        reason: 'A pause ends the utterance, not the listening session -- the '
            'microphone must stay open so the speaker can continue.',
      );

      speech.emit('second sentence', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((c) => c.text).toList(),
        <String>['hello there', 'second sentence'],
        reason: 'Continuing to speak must produce a new caption, not repeat '
            'the first recognised utterance.',
      );
    });

    test('speaking again before the pause elapses keeps both utterances', () async {
      final speech = _ScriptedSpeechProvider();
      final conversation = ConversationProvider();
      final engine = ConversationEngine(speech: speech, conversation: conversation);
      addTearDown(() {
        engine.dispose();
        conversation.dispose();
        speech.dispose();
      });

      conversation.startConversation();
      await engine.setPauseThreshold(const Duration(milliseconds: 900));
      engine.startListening();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Two finals in quick succession: the pause never elapses between them,
      // so they belong to the same turn and neither may be dropped.
      speech.emit('first part', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      speech.emit('second part', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(
        conversation.captions.map((c) => c.text).toList(),
        <String>['first part second part'],
        reason: 'Replacing rather than accumulating the turn text silently '
            'discarded the earlier utterance.',
      );
    });
  });

  group('Caption commit', () {
    // Note: this guards the correct contract but does not by itself reproduce
    // the original failure, which needed
    // DeepgramTranscriptionService.lastFinalTranscript to already hold a stale
    // value from an earlier fallback session. That singleton is empty in a
    // fresh test process and cannot be seeded from outside the service, so the
    // fix is proven by the removal of the cross-service read itself.
    test('commits the recognised text, not a stale value from another service', () {
      final conversation = ConversationProvider();
      addTearDown(conversation.dispose);

      conversation.startConversation();
      conversation.beginSpeakerTurn(language: 'English');
      conversation.updateSpeakerTurn('the newest sentence', language: 'English');
      conversation.commitSpeakerTurn();

      expect(
        conversation.captions.single.text,
        'the newest sentence',
        reason: 'commitSpeakerTurn used to overwrite the draft with '
            'DeepgramTranscriptionService.lastFinalTranscript -- a singleton '
            'owned by a different STT implementation that Everyday Mode never '
            'starts, so captions kept repeating a stale utterance.',
      );
    });
  });

  group('Brand badge', () {
    testWidgets('renders the mark on the brand green launcher-icon background',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandLogo(size: 56))),
      );

      final container = tester.widget<Container>(
        find
            .descendant(of: find.byType(BrandLogo), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(
        decoration.color,
        AppTokens.brandIconBackground,
        reason: 'The badge must keep the green brand treatment: the mark asset '
            'is transparent, so filling with colorScheme.surface left it '
            'floating on white.',
      );
    });
  });
}
