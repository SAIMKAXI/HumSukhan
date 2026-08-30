import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'audio_model_manager.dart';

/// Dedicated sherpa-ONNX audio tagger for environmental sound classification.
///
/// Wraps [sherpa_onnx.AudioTagging] with the CED-Tiny INT8 model. Handles:
/// - One-time initialization when monitoring starts
/// - Model/label loading from app-private cache
/// - PCM16→Float32 conversion and waveform submission
/// - Top-K label+probability results
/// - Clean release when monitoring stops
///
/// Does NOT manage microphone, cooldown, or event mapping — those belong
/// to [SoundDetectionService].
class SherpaAudioTagger {
  sherpa_onnx.AudioTagging? _tagger;
  sherpa_onnx.OfflineStream? _stream;
  List<String> _labels = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<String> get labels => List.unmodifiable(_labels);

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Initialize the tagger: load CED-Tiny INT8 model and labels.
  ///
  /// Call once when monitoring starts. The model stays in memory until
  /// [release] is called.
  Future<bool> initialize() async {
    if (_initialized) return _tagger != null;

    try {
      final mm = AudioModelManager.instance;
      if (mm.modelPath == null || mm.labelsPath == null) {
        debugPrint('SherpaAudioTagger: model paths not ready');
        return false;
      }

      // Load labels from CSV (index,name format)
      _labels = await _loadLabels(mm.labelsPath!);

      // Create the sherpa-ONNX AudioTagging instance
      final config = sherpa_onnx.AudioTaggingConfig(
        model: sherpa_onnx.AudioTaggingModelConfig(
          ced: mm.modelPath!,
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        ),
        labels: mm.labelsPath!,
      );

      _tagger = sherpa_onnx.AudioTagging(config: config);
      _stream = _tagger!.createStream();
      _initialized = true;

      debugPrint('SherpaAudioTagger: ready (${_labels.length} labels)');
      return true;
    } catch (e) {
      debugPrint('SherpaAudioTagger init failed: $e');
      _initialized = false;
      return false;
    }
  }

  /// Release the ONNX model and free native resources.
  ///
  /// Must be called when monitoring stops so the model is not held in RAM.
  void release() {
    try {
      _stream?.free();
    } catch (_) {}
    _stream = null;

    try {
      _tagger?.free();
    } catch (_) {}
    _tagger = null;

    _initialized = false;
    debugPrint('SherpaAudioTagger: released');
  }

  // ── Inference ──────────────────────────────────────────────────────

  /// Classify a window of audio and return the top [topK] predictions.
  ///
  /// [samples] must be Float32 PCM normalised to [-1, 1] at 16 kHz mono.
  /// Returns a list of [SherpaAudioResult] sorted by probability descending.
  List<SherpaAudioResult> classify({
    required Float32List samples,
    int sampleRate = 16000,
    int topK = 10,
  }) {
    if (_tagger == null || _stream == null) {
      return const <SherpaAudioResult>[];
    }

    try {
      _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);
      final events = _tagger!.compute(stream: _stream!, topK: topK);

      return events
          .map((e) => SherpaAudioResult(label: e.name, probability: e.prob))
          .toList();
    } catch (e) {
      debugPrint('SherpaAudioTagger classify error: $e');
      return const <SherpaAudioResult>[];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  /// Parse the CSV label file: `index,name` per line.
  Future<List<String>> _loadLabels(String csvPath) async {
    try {
      final file = File(csvPath);
      final content = await file.readAsString();
      final labels = <String>[];

      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('index')) continue;

        final idx = trimmed.indexOf(',');
        if (idx != -1) {
          final name = trimmed.substring(idx + 1).trim();
          if (name.isNotEmpty) labels.add(name);
        }
      }
      return labels;
    } catch (e) {
      debugPrint('SherpaAudioTagger: label load error: $e');
      return [];
    }
  }
}

/// A single audio-tagging prediction.
class SherpaAudioResult {
  final String label;
  final double probability;

  const SherpaAudioResult({required this.label, required this.probability});

  @override
  String toString() => '$label (${(probability * 100).toStringAsFixed(1)}%)';
}
