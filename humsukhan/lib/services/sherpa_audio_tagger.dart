import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'audio_model_manager.dart';

class SherpaAudioTagger {
  sherpa_onnx.AudioTagging? _tagger;
  sherpa_onnx.OfflineStream? _stream;
  List<String> _labels = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<String> get labels => List.unmodifiable(_labels);

  Future<bool> initialize() async {
    if (_initialized) return _tagger != null;
    try {
      final mm = AudioModelManager.instance;
      if (mm.modelPath == null || mm.labelsPath == null) {
        debugPrint('SherpaAudioTagger: local model paths are not ready');
        return false;
      }
      _labels = await _loadLabels(mm.labelsPath!);
      if (_labels.isEmpty) return false;
      final config = sherpa_onnx.AudioTaggingConfig(
        model: sherpa_onnx.AudioTaggingModelConfig(
          ced: mm.modelPath!, numThreads: 1, provider: 'cpu', debug: false,
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
      release();
      return false;
    }
  }

  void release() {
    try { _stream?.free(); } catch (_) {}
    _stream = null;
    try { _tagger?.free(); } catch (_) {}
    _tagger = null;
    _labels = [];
    _initialized = false;
  }

  List<SherpaAudioResult> classify({required Float32List samples, int sampleRate = 16000, int topK = 10}) {
    if (_tagger == null || _stream == null) return const <SherpaAudioResult>[];
    try {
      _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);
      final events = _tagger!.compute(stream: _stream!, topK: topK);
      return events.map((e) => SherpaAudioResult(label: e.name, probability: e.prob)).toList();
    } catch (e) {
      debugPrint('SherpaAudioTagger classify error: $e');
      return const <SherpaAudioResult>[];
    }
  }

  Future<List<String>> _loadLabels(String csvPath) async {
    try {
      final content = await File(csvPath).readAsString();
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

class SherpaAudioResult {
  final String label;
  final double probability;
  const SherpaAudioResult({required this.label, required this.probability});
  @override
  String toString() => '$label (${(probability * 100).toStringAsFixed(1)}%)';
}
