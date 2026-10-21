import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/background/environmental_background_pipeline.dart';
import 'package:humsukhan/modules/environmental_alerts/services/android_service_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_alert_pipeline.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_detection_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidServiceMonitor.methodChannelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> toNative;
  late FakeClassifier classifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    toNative = [];
    classifier = FakeClassifier(tags: [(label: 'Knock', probability: 0.8)]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      toNative.add(call);
      return true;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> run() => runEnvironmentalBackgroundPipeline(
        engine: (onDetected) => SoundDetectionEngine(onDetected: onDetected, classifier: classifier),
        pipeline: EnvironmentalAlertPipeline(announce: (_, _) async {}),
      );

  /// Sends a call from "native" to the Dart handler.
  Future<Object?> fromNative(String method, [Object? arguments]) async {
    final reply = await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      null,
    );
    return reply == null ? null : channel.codec.decodeEnvelope(reply);
  }

  test('reports READY only once the model has loaded', () async {
    await run();
    expect(toNative.single.method, 'pipelineState');
    expect(toNative.single.arguments, {'state': 'READY'});
  });

  test('reports a model failure so the service does not open the microphone', () async {
    classifier.loads = false;
    await run();
    expect(toNative.single.arguments, {'state': 'ERROR', 'error': 'MODEL'});
  });

  test('confirms audio once, on the first PCM it receives', () async {
    await run();
    await fromNative('audioData', tone(0.25, 10));
    await fromNative('audioData', tone(0.25, 10));
    final flowing = toNative.where((c) => c.method == 'pipelineState' && (c.arguments as Map)['state'] == 'PCM_FLOWING');
    expect(flowing, hasLength(1));
  });

  test('an announced alert is passed to the service as the stored event', () async {
    await run();
    await fromNative('audioData', tone(3, 4000));
    await pumpEventQueue();

    final event = toNative.singleWhere((c) => c.method == 'event');
    final decoded = jsonDecode((event.arguments as Map)['event'] as String) as Map;
    expect(decoded['type'], 'Knock');
    expect(decoded['id'], isA<String>());
  });

  test('stop releases the model', () async {
    await run();
    await fromNative('stop');
    expect(classifier.releaseCalls, 1);
  });
}
