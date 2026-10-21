import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_detection_engine.dart';

import 'fakes.dart';

void main() {
  late FakeClassifier classifier;
  late List<SoundEvent> detected;
  late SoundDetectionEngine engine;

  setUp(() {
    classifier = FakeClassifier(tags: [(label: 'Doorbell', probability: 0.9)]);
    detected = [];
    engine = SoundDetectionEngine(onDetected: detected.add, classifier: classifier);
  });

  test('a loud three-second window is classified and reported', () async {
    expect(await engine.start(), isTrue);
    engine.addPcm(tone(3, 3000));
    expect(classifier.classifyCalls, 1);
    expect(detected.single.type, 'Doorbell');
  });

  test('nothing is reported before three seconds of audio have arrived', () async {
    await engine.start();
    engine.addPcm(tone(2.9, 3000));
    expect(classifier.classifyCalls, 0);
  });

  test('silence is never sent to the model', () async {
    await engine.start();
    engine.addPcm(tone(3, 50));
    expect(classifier.classifyCalls, 0);
    expect(detected, isEmpty);
  });

  test('if the model cannot load the engine stays stopped and ignores audio', () async {
    classifier.loads = false;
    expect(await engine.start(), isFalse);
    expect(engine.isRunning, isFalse);
    engine.addPcm(tone(3, 3000));
    expect(classifier.classifyCalls, 0);
  });

  test('stop releases the model, and a later start works from scratch', () async {
    await engine.start();
    engine.addPcm(tone(3, 3000));
    engine.stop();
    expect(classifier.releaseCalls, 1);
    engine.addPcm(tone(3, 3000));
    expect(detected, hasLength(1));

    expect(await engine.start(), isTrue);
    expect(classifier.loadCalls, 2);
    // The cooldown from the first run does not carry over.
    engine.addPcm(tone(3, 3000));
    expect(detected, hasLength(2));
  });
}
