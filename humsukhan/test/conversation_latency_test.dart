import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/providers/conversation_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';

import 'environmental/fakes.dart';

/// Speech that starts at once, for the conversation engine.
class _InstantSpeech extends EverydaySpeechProvider {
  final StreamController<SpeechResultEvent> controller = StreamController.broadcast();
  final Completer<void> voices = Completer<void>();
  bool _listening = false;

  @override
  Stream<SpeechResultEvent> get onResult => controller.stream;
  @override
  bool get isListening => _listening;
  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}

  /// Loading the voices never finishes.
  @override
  Future<void> warmUpTts() => voices.future;

  @override
  Future<void> startListening({String language = 'English'}) async => _listening = true;
  @override
  Future<void> stopListening() async => _listening = false;

  void emit(String text, {required bool isFinal}) => controller.add(SpeechResultEvent(
        text: text,
        isFinal: isFinal,
        confidence: 0.9,
        language: 'English',
        isLive: true,
        mode: STTMode.platform,
      ));
}

class _CloudStream implements EverydayBilingualSttService {
  final StreamController<EverydayBilingualResult> results = StreamController.broadcast(sync: true);
  final StreamController<String> lost = StreamController.broadcast(sync: true);
  @override
  Stream<EverydayBilingualResult> get onResult => results.stream;
  @override
  Stream<String> get onConnectionLost => lost.stream;
  @override
  Stream<void> get onVoiceStarted => const Stream.empty();
  @override
  String? get lastStartError => null;
  @override
  Future<bool> start({String mode = 'Auto'}) async => true;
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fallback implements EnhancedSpeechProvider {
  _Fallback({this.loading = Duration.zero});
  final Duration loading;
  @override
  Stream<SpeechResultEvent> get onResult => const Stream.empty();
  @override
  STTMode get currentMode => STTMode.none;
  @override
  bool deviceSupports(String language) => false;
  @override
  bool offlineReady(String language) => false;
  @override
  Future<void> initialize() => Future<void>.delayed(loading);
  @override
  Future<void> stopListening() async {}
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Speech extends EverydaySpeechProvider {
  _Speech({
    Duration network = Duration.zero,
    Duration loading = Duration.zero,
    super.resumeDelay,
    super.conversationResumeDelay,
  }) : super(
          cloudReachable: () => Future<bool>.delayed(network, () => true),
          cloudStream: _CloudStream(),
          fallback: _Fallback(loading: loading),
        );
  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late FakeMonitor monitor;
  setUp(() {
    monitor = FakeMonitor();
    EnvironmentalMonitoring.instance = monitor;
  });

  group('Conversation captions', () {
    test('words show on screen as they are recognized, before the pause ends the caption', () async {
      final speech = _InstantSpeech();
      final conversation = ConversationProvider()..startConversation();
      final engine = ConversationEngine(speech: speech, conversation: conversation);
      addTearDown(engine.dispose);

      engine.startListening();
      await _settle();
      speech.emit('hello wor', isFinal: false);
      await _settle();
      expect(conversation.currentPartial?.text, 'hello wor');

      speech.emit('hello world', isFinal: true);
      await _settle();
      expect(conversation.currentPartial?.text, 'hello world');
      expect(conversation.captions, isEmpty, reason: 'the pause has not ended the caption yet');
    });

    test('the microphone does not wait for the voices to load', () async {
      final speech = _InstantSpeech();
      final conversation = ConversationProvider();
      final engine = ConversationEngine(speech: speech, conversation: conversation);
      addTearDown(engine.dispose);

      engine.startConversation();
      engine.startListening();
      await _settle();
      expect(engine.state, ConversationEngineState.listening);
    });
  });

  group('Starting to listen', () {
    test('the start-up checks run side by side, not one after another', () async {
      final speech = _Speech(
        network: const Duration(milliseconds: 400),
        loading: const Duration(milliseconds: 400),
      );
      final clock = Stopwatch()..start();
      await speech.startListening(language: 'Auto');
      clock.stop();
      expect(speech.isListening, isTrue);
      expect(clock.elapsedMilliseconds, lessThan(700));
    });

    test('one cloud token is fetched and reused until it is about to expire', () async {
      final service = EverydayBilingualSttService.instance;
      var issued = 0;
      var lifetime = const Duration(hours: 1);
      service.debugForgetToken();
      service.debugTokenSource = () async {
        issued++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return (token: 'token-$issued', lifetime: lifetime);
      };
      addTearDown(() {
        service.debugTokenSource = null;
        service.debugForgetToken();
      });

      await Future.wait([service.prewarm(), service.prewarm()]);
      await service.prewarm();
      expect(issued, 1);

      service.debugForgetToken();
      lifetime = const Duration(minutes: 1);
      await service.prewarm();
      await service.prewarm();
      expect(issued, 3, reason: 'a token about to expire is not reused');
    });
  });

  group('Environmental monitoring during a conversation', () {
    // The real delays are 3 s, and 20 s while a conversation is open.
    _Speech speech() => _Speech(
          resumeDelay: const Duration(milliseconds: 30),
          conversationResumeDelay: const Duration(milliseconds: 300),
        );

    setUp(() async {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await monitor.start();
    });

    test('stays paused between turns, and resumes soon after the conversation ends', () async {
      final s = speech();
      await s.startListening(language: 'Auto');
      expect(monitor.status, MonitoringStatus.off);
      s.holdMicrophoneForConversation(true);
      await s.stopListening();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(monitor.status, MonitoringStatus.off, reason: 'the next turn would have to stop it again');

      s.holdMicrophoneForConversation(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(monitor.status, MonitoringStatus.active);
    });

    test('an open conversation left idle gives the microphone back to monitoring', () async {
      final s = speech();
      await s.startListening(language: 'Auto');
      s.holdMicrophoneForConversation(true);
      await s.stopListening();

      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(monitor.status, MonitoringStatus.active);
    });

    test('outside a conversation it resumes after the usual short delay', () async {
      final s = speech();
      await s.startListening(language: 'English');
      await s.stopListening();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(monitor.status, MonitoringStatus.active);
    });
  });
}
