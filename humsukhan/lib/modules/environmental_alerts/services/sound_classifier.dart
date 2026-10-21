import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'sound_alert_policy.dart';

/// Tags a window of 16 kHz mono audio with AudioSet labels.
abstract class SoundClassifier {
  /// Loads the model. Returns false if it cannot be used.
  Future<bool> load();

  List<SoundTag> classify(Float32List samples);

  /// Frees the model. [load] may be called again afterwards.
  void release();
}

/// The CED-Tiny audio tagger shipped inside the app, run with sherpa-onnx.
///
/// Monitoring never touches the network: the model is copied out of the
/// application bundle, because sherpa-onnx needs a file path.
class SherpaSoundClassifier implements SoundClassifier {
  static const _modelAsset = 'assets/environmental/model.int8.onnx';
  static const _labelsAsset = 'assets/environmental/class_labels_indices.csv';
  static const _modelDirName = 'sherpa_ced_tiny';

  sherpa_onnx.AudioTagging? _tagger;

  @override
  Future<bool> load() async {
    if (_tagger != null) return true;
    try {
      final dir = await getApplicationSupportDirectory();
      final modelDir = Directory('${dir.path}/$_modelDirName');
      await modelDir.create(recursive: true);
      final model = await _installAsset(_modelAsset, File('${modelDir.path}/model.int8.onnx'));
      final labels = await _installAsset(_labelsAsset, File('${modelDir.path}/class_labels_indices.csv'));
      sherpa_onnx.initBindings();
      _tagger = sherpa_onnx.AudioTagging(
        config: sherpa_onnx.AudioTaggingConfig(
          model: sherpa_onnx.AudioTaggingModelConfig(ced: model.path, numThreads: 1, provider: 'cpu', debug: false),
          labels: labels.path,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Environmental model could not be loaded: $e');
      release();
      return false;
    }
  }

  /// Copies a bundled asset to [target] unless an identical-size copy is
  /// already there, so an app update that ships a new model replaces the old
  /// one instead of silently running it forever.
  Future<File> _installAsset(String asset, File target) async {
    final data = await rootBundle.load(asset);
    if (await target.exists() && await target.length() == data.lengthInBytes) return target;
    final part = File('${target.path}.part');
    await part.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    return part.rename(target.path);
  }

  @override
  List<SoundTag> classify(Float32List samples) {
    final tagger = _tagger;
    if (tagger == null) return const [];
    // CED tagging is offline: each window needs its own stream, or audio from
    // earlier windows accumulates into the next classification.
    sherpa_onnx.OfflineStream? stream;
    try {
      stream = tagger.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      return [
        for (final event in tagger.compute(stream: stream, topK: 10))
          (label: event.name, probability: event.prob),
      ];
    } catch (e) {
      debugPrint('Environmental classification failed: $e');
      return const [];
    } finally {
      stream?.free();
    }
  }

  @override
  void release() {
    try {
      _tagger?.free();
    } catch (e) {
      debugPrint('Environmental model release failed: $e');
    }
    _tagger = null;
  }
}
