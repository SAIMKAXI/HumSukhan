import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/speech_engine.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';
import 'package:humsukhan/services/stt/stt_plan.dart';

import 'environmental/fakes.dart';

class _FakeCloudStream implements EverydayBilingualSttService {
  bool startResult = true;
  final List<String> started = [];
  int stops = 0;
  final StreamController<EverydayBilingualResult> results = StreamController.broadcast(sync: true);
  final StreamController<String> lost = StreamController.broadcast(sync: true);

  @override
  Stream<EverydayBilingualResult> get onResult => results.stream;
  @override
  Stream<String> get onConnectionLost => lost.stream;
  @override
  String? get lastStartError => startResult ? null : 'cloud refused';

  @override
  Future<bool> start({String mode = 'Auto'}) async {
    started.add(mode);
    return startResult;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFallback implements EnhancedSpeechProvider {
  Set<String> device = {};
  Set<String> offline = {};

  /// Routes that refuse to start.
  Set<SttRoute> failing = {};
  final List<String> started = [];
  STTMode _mode = STTMode.none;
  final StreamController<SpeechResultEvent> results = StreamController.broadcast(sync: true);

  @override
  Stream<SpeechResultEvent> get onResult => results.stream;
  @override
  STTMode get currentMode => _mode;
  @override
  String? get lastStartError => '${started.last} refused';
  @override
  bool deviceSupports(String language) => device.contains(language);
  @override
  bool offlineReady(String language) => offline.contains(language);
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> start(SttRoute route, {required String language, bool bilingual = false}) async {
    started.add('${route.name}:$language${bilingual ? ' (bilingual)' : ''}');
    if (failing.contains(route)) return false;
    _mode = switch (route) {
      SttRoute.device => STTMode.platform,
      SttRoute.cloudChunk => STTMode.cloudBatch,
      SttRoute.offline => STTMode.sherpaStreaming,
    };
    return true;
  }

  @override
  Future<void> stopListening() async => _mode = STTMode.none;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real provider with TTS start-up skipped.
class _Speech extends EverydaySpeechProvider {
  _Speech({required bool online, required super.cloudStream, required super.fallback})
      : super(cloudReachable: () async => online);

  @override
  Future<void> initialize({String preferredLanguage = 'English'}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // The provider builds a real TTS and audio stack; none of it is used here.
  for (final channel in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers', 'flutter_tts']) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }

  late _FakeCloudStream cloud;
  late _FakeFallback fallback;

  setUp(() {
    EnvironmentalMonitoring.instance = FakeMonitor();
    cloud = _FakeCloudStream();
    fallback = _FakeFallback();
  });

  _Speech speech({bool online = true}) => _Speech(online: online, cloudStream: cloud, fallback: fallback);

  test('English with the phone recognizer installed uses the phone, not the cloud', () async {
    fallback.device = {'English'};
    final s = speech();
    await s.startListening(language: 'English');
    expect(s.isListening, isTrue);
    expect(s.activeSource, SpeechSource.device);
    expect(fallback.started, ['device:English']);
    expect(cloud.started, isEmpty);
  });

  test('Urdu without the phone locale goes to the live cloud stream', () async {
    fallback.device = {'English'};
    final s = speech();
    await s.startListening(language: 'Urdu');
    expect(s.activeSource, SpeechSource.cloudStream);
    expect(cloud.started, ['Urdu']);
  });

  test('a stalled cloud stream hands over to the next recognizer, still bilingual in Auto', () async {
    fallback.device = {'English'};
    final s = speech();
    await s.startListening(language: 'Auto');
    expect(s.activeSource, SpeechSource.cloudStream);

    cloud.lost.add('The cloud recognizer is not returning captions.');
    await pumpEventQueue();
    expect(cloud.stops, greaterThan(0));
    expect(fallback.started, ['cloudChunk:Auto (bilingual)']);
    expect(s.isListening, isTrue);
    expect(s.activeSource, SpeechSource.cloudChunk);
  });

  test('when nothing after the cloud can start, the conversation is told why', () async {
    fallback.failing = SttRoute.values.toSet();
    final s = speech();
    final errors = <Object>[];
    s.onResult.listen((_) {}, onError: errors.add);
    await s.startListening(language: 'Auto');
    cloud.lost.add('The microphone is sending silence.');
    await pumpEventQueue();
    expect(s.isListening, isFalse);
    expect(errors.single, isA<SpeechInterruption>());
    expect((errors.single as SpeechInterruption).message, contains('silence'));
  });

  test('with no connection the cloud is not tried and the offline model is used', () async {
    fallback.offline = {'Urdu'};
    final s = speech(online: false);
    await s.startListening(language: 'Urdu');
    expect(cloud.started, isEmpty);
    expect(fallback.started, ['offline:Urdu']);
    expect(s.isOfflineMode, isTrue);
  });

  test('a cloud stream that will not start falls through to the backup', () async {
    cloud.startResult = false;
    final s = speech();
    await s.startListening(language: 'English');
    expect(fallback.started, ['cloudChunk:English']);
    expect(s.activeSource, SpeechSource.cloudChunk);
  });

  test('offline with no model says to download one', () async {
    final s = speech(online: false);
    await s.startListening(language: 'Urdu');
    expect(s.isListening, isFalse);
    expect(s.lastStartError, contains('Download one in Settings'));
  });

  test('Roman Urdu captions are recognized as Urdu', () async {
    final s = speech();
    await s.startListening(language: 'Roman Urdu');
    expect(cloud.started, ['Urdu']);
  });
}
