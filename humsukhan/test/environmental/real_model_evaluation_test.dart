// Runs labelled audio clips through the real bundled model and the app's
// own detection pipeline. Skipped unless both are available:
//
//   bash tool/prepare_environmental_model.sh
//   HUMSUKHAN_SOUND_CLIPS=/path/to/clips \
//   LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-<version>/linux/x64 \
//   flutter test test/environmental/real_model_evaluation_test.dart
//
// Clips are 16 kHz mono 16-bit WAV, named `<label>__<anything>.wav`. A label
// containing "siren" expects a Siren alert, "knock" a Knock, "doorbell" a
// Doorbell; any other label expects no alert at all. ESC-50
// (github.com/karolpiczak/ESC-50) resampled with
// `ffmpeg -i in.wav -ar 16000 -ac 1 -sample_fmt s16 out.wav` works well.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_classifier.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_detection_engine.dart';

String? expectedAlert(String label) {
  if (label.contains('siren')) return 'Siren';
  if (label.contains('knock')) return 'Knock';
  if (label.contains('doorbell')) return 'Doorbell';
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clipsPath = Platform.environment['HUMSUKHAN_SOUND_CLIPS'];
  final model = File('assets/environmental/model.int8.onnx');
  final skip = clipsPath == null
      ? 'Set HUMSUKHAN_SOUND_CLIPS to a folder of labelled clips'
      : (!model.existsSync() || model.lengthSync() < 1000000)
          ? 'Run tool/prepare_environmental_model.sh first'
          : false;

  test('real model: alerts on the sounds it should and on nothing else', () async {
    final support = Directory.systemTemp.createTempSync('humsukhan_env');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => support.path,
    );
    final classifier = SherpaSoundClassifier();
    expect(await classifier.load(), isTrue, reason: 'model failed to load (is LD_LIBRARY_PATH set?)');

    final clips = Directory(clipsPath!).listSync().whereType<File>().where((f) => f.path.endsWith('.wav')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final hits = <String, int>{};
    final totals = <String, int>{};
    final falseAlerts = <String>[];

    for (final clip in clips) {
      final name = clip.uri.pathSegments.last;
      final expected = expectedAlert(name.split('__').first.toLowerCase());
      final alerts = <SoundEvent>[];
      // The production engine, fed in the 8 KB chunks Android's recorder uses.
      final engine = SoundDetectionEngine(onDetected: alerts.add, classifier: _Shared(classifier));
      await engine.start();
      final pcm = clip.readAsBytesSync().sublist(44);
      for (var i = 0; i < pcm.length; i += 8192) {
        engine.addPcm(Uint8List.sublistView(pcm, i, (i + 8192).clamp(0, pcm.length)));
      }
      final types = alerts.map((e) => e.type).toSet();
      final key = expected ?? 'none';
      totals[key] = (totals[key] ?? 0) + 1;
      if (expected != null && types.contains(expected)) hits[key] = (hits[key] ?? 0) + 1;
      if (types.difference({?expected}).isNotEmpty) falseAlerts.add('$name → ${types.join(', ')}');
    }

    for (final entry in totals.entries.where((e) => e.key != 'none')) {
      // ignore: avoid_print
      print('${entry.key}: ${hits[entry.key] ?? 0}/${entry.value} detected');
    }
    // ignore: avoid_print
    print('false alerts: ${falseAlerts.length}/${clips.length}\n  ${falseAlerts.join('\n  ')}');

    final sirens = totals['Siren'] ?? 0;
    if (sirens > 0) expect((hits['Siren'] ?? 0) / sirens, greaterThanOrEqualTo(0.9), reason: 'siren recall');
    expect(falseAlerts.length / clips.length, lessThanOrEqualTo(0.02), reason: falseAlerts.join('\n'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}

/// Lets every clip reuse one loaded model.
class _Shared implements SoundClassifier {
  _Shared(this._inner);
  final SoundClassifier _inner;
  @override
  Future<bool> load() async => true;
  @override
  List<({String label, double probability})> classify(Float32List samples) => _inner.classify(samples);
  @override
  void release() {}
}
