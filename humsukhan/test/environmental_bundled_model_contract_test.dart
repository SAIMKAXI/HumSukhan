import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environmental model is bundled and runtime monitoring has no network dependency', () {
    final manager = File('lib/services/audio_model_manager.dart').readAsStringSync();
    final detector = File('lib/services/sound_detection_service.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('assets/environmental/model.int8.onnx'));
    expect(pubspec, contains('assets/environmental/class_labels_indices.csv'));
    expect(manager, contains("rootBundle.load(_modelAsset)"));
    expect(manager, contains("rootBundle.load(_labelsAsset)"));
    expect(manager, isNot(contains('package:http/http.dart')));
    expect(manager, isNot(contains('huggingface.co')));
    expect(detector, contains('AudioModelManager.instance.initialize()'));
    expect(detector, isNot(contains('downloadModel()')));
  });
}
