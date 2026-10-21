import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_alert_pipeline.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/in_app_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_detection_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FakePcmSource> sources;
  late FakeClassifier classifier;
  late List<SoundEvent> announced;
  late InAppMonitor monitor;
  late List<MonitorUpdate> updates;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sources = [];
    classifier = FakeClassifier(tags: [(label: 'Siren', probability: 0.95)]);
    announced = [];
    monitor = InAppMonitor(
      source: () {
        sources.add(FakePcmSource());
        return sources.last;
      },
      engine: (onDetected) => SoundDetectionEngine(onDetected: onDetected, classifier: classifier),
      pipeline: EnvironmentalAlertPipeline(announce: (event, _) async => announced.add(event)),
    );
    updates = [];
    monitor.updates.listen(updates.add);
  });

  test('start goes through STARTING to ACTIVE with the microphone open', () async {
    await monitor.start();
    await pumpEventQueue();
    expect(monitor.status, MonitoringStatus.active);
    expect(updates.map((u) => u.status), [MonitoringStatus.starting, MonitoringStatus.active]);
    expect(sources.last.startCalls, 1);
  });

  test('a detected sound is recorded, announced and reported to the screen', () async {
    await monitor.start();
    sources.last.audio.add(tone(3, 4000));
    await pumpEventQueue();

    expect(announced.single.type, 'Siren');
    expect(updates.last.alert?.type, 'Siren');
    expect(monitor.status, MonitoringStatus.active);
  });

  test('stop releases the microphone and the model', () async {
    await monitor.start();
    await monitor.stop();
    expect(monitor.status, MonitoringStatus.off);
    expect(sources.last.stopCalls, 1);
    expect(classifier.releaseCalls, 1);
  });

  test('monitoring can be started again after it was stopped', () async {
    // The previous detector kept an init flag across stop, so every start
    // after the first failed with "Microphone access is unavailable".
    await monitor.start();
    await monitor.stop();
    await monitor.start();
    expect(monitor.status, MonitoringStatus.active);
    expect(sources, hasLength(2));
  });

  test('no microphone access is reported as such, with nothing left open', () async {
    monitor = InAppMonitor(
      source: () => FakePcmSource(permitted: false),
      engine: (onDetected) => SoundDetectionEngine(onDetected: onDetected, classifier: classifier),
    );
    await monitor.start();
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.microphoneUnavailable);
    expect(monitor.failure!.needsSystemSettings, isTrue);
    expect(classifier.loadCalls, 0);
  });

  test('a model that will not load is reported as a model failure and the recorder is never opened', () async {
    classifier.loads = false;
    await monitor.start();
    expect(monitor.failure, MonitoringFailure.model);
    expect(sources.last.startCalls, 0);
    expect(sources.last.stopCalls, 1);
  });

  test('a recorder that cannot start is a capture failure and frees the model', () async {
    monitor = InAppMonitor(
      source: () => FakePcmSource(startError: Exception('busy')),
      engine: (onDetected) => SoundDetectionEngine(onDetected: onDetected, classifier: classifier),
    );
    await monitor.start();
    expect(monitor.failure, MonitoringFailure.capture);
    expect(classifier.releaseCalls, 1);
  });

  test('losing the audio stream while active is reported, not silently ignored', () async {
    await monitor.start();
    await sources.last.audio.close();
    await pumpEventQueue();
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.capture);
  });

  test('releasing the microphone for speech stops monitoring', () async {
    await monitor.start();
    expect(await monitor.releaseMicrophone(), isTrue);
    expect(monitor.status, MonitoringStatus.off);
    expect(sources.last.stopCalls, 1);
  });

  test('releasing the microphone when monitoring is off does nothing', () async {
    expect(await monitor.releaseMicrophone(), isTrue);
    expect(sources, isEmpty);
  });
}
