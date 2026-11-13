import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/speech_engine.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';

import 'environmental/fakes.dart';

/// A cloud stream whose start finishes when the test says so.
class _SlowCloud implements EverydayBilingualSttService {
  Completer<bool> pending = Completer<bool>();
  int stops = 0;
  bool running = false;
  final StreamController<EverydayBilingualResult> results = StreamController.broadcast(sync: true);
  final StreamController<String> lost = StreamController.broadcast(sync: true);

  @override
  Stream<EverydayBilingualResult> get onResult => results.stream;
  @override
  Stream<String> get onConnectionLost => lost.stream;
  @override
  Stream<void> get onVoiceStarted => const Stream.empty();
  @override
  String? get lastStartError => 'cloud refused';

  @override
  Future<bool> start({String mode = 'Auto'}) async {
    final started = await pending.future;
    running = started;
    return started;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fallback implements EnhancedSpeechProvider {
  bool offlineAvailable = false;
  bool running = false;

  /// Every route refuses to start.
  bool refuse = false;
  final StreamController<SpeechResultEvent> results = StreamController.broadcast(sync: true);

  @override
  Stream<SpeechResultEvent> get onResult => results.stream;
  @override
  STTMode get currentMode => running ? STTMode.sherpaStreaming : STTMode.none;
  @override
  String? get lastStartError => 'offline refused';
  @override
  bool deviceSupports(String language) => false;
  @override
  bool offlineReady(String language) => offlineAvailable;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> start(SttRoute route, {required String language, bool bilingual = false}) async => running = !refuse;
  @override
  Future<void> stopListening() async => running = false;
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Speech extends EverydaySpeechProvider {
  _Speech(_SlowCloud cloud, _Fallback fallback) : super(cloudReachable: () async => true, cloudStream: cloud, fallback: fallback);

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late _SlowCloud cloud;
  late _Fallback fallback;
  late _Speech speech;

  setUp(() {
    EnvironmentalMonitoring.instance = FakeMonitor();
    cloud = _SlowCloud();
    fallback = _Fallback();
    speech = _Speech(cloud, fallback);
  });

  test('a start goes idle → starting → listening', () async {
    expect(speech.listeningPhase, ListeningPhase.idle);
    final start = speech.startListening(language: 'Urdu');
    await pumpEventQueue();
    expect(speech.listeningPhase, ListeningPhase.starting);
    cloud.pending.complete(true);
    await start;
    expect(speech.listeningPhase, ListeningPhase.listening);
    expect(speech.isListening, isTrue);
  });

  test('stopping while a recognizer is still starting leaves the microphone off', () async {
    final start = speech.startListening(language: 'Urdu');
    await pumpEventQueue();
    await speech.stopListening();
    // The cloud finishes connecting only after the stop.
    cloud.pending.complete(true);
    await start;

    expect(speech.listeningPhase, ListeningPhase.idle);
    expect(speech.isListening, isFalse);
    expect(cloud.running, isFalse, reason: 'the late recognizer was stopped again');
  });

  test('a second start while one is in progress does nothing', () async {
    final first = speech.startListening(language: 'Urdu');
    await pumpEventQueue();
    await speech.startListening(language: 'Urdu');
    expect(speech.listeningPhase, ListeningPhase.starting);
    cloud.pending.complete(true);
    await first;
    expect(speech.listeningPhase, ListeningPhase.listening);
  });

  test('when the cloud drops, the next recognizer takes over', () async {
    fallback.offlineAvailable = true;
    final start = speech.startListening(language: 'Urdu');
    cloud.pending.complete(true);
    await start;

    cloud.lost.add('connection lost');
    await pumpEventQueue();
    expect(speech.listeningPhase, ListeningPhase.listening);
    expect(fallback.running, isTrue);
  });

  test('when the cloud drops and nothing can take over, listening stops with the reason', () async {
    fallback.refuse = true;
    final errors = <Object>[];
    final sub = speech.onResult.listen((_) {}, onError: errors.add);
    addTearDown(sub.cancel);
    final start = speech.startListening(language: 'Urdu');
    cloud.pending.complete(true);
    await start;

    cloud.lost.add('connection lost');
    await pumpEventQueue();
    expect(speech.listeningPhase, ListeningPhase.idle);
    expect(errors.single, isA<SpeechInterruption>());
  });

}
