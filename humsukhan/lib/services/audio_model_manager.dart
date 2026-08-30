import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages the sherpa-onnx CED-Tiny audio tagging model.
///
/// Model discovery is deliberately offline-only. Monitoring never performs a
/// network request. A download is an explicit setup operation and is never
/// used as an implicit fallback while monitoring is starting.
class AudioModelManager {
  static AudioModelManager? _instance;
  static AudioModelManager get instance => _instance ??= AudioModelManager._();
  AudioModelManager._();

  static const String _modelFileName = 'model.int8.onnx';
  static const String _labelsFileName = 'class_labels_indices.csv';
  static const String _modelDirName = 'sherpa_ced_tiny';

  static const String _modelUrl =
      'https://huggingface.co/k2-fsa/sherpa-onnx-ced-tiny-audio-tagging-2024-04-19/resolve/main/model.int8.onnx';
  static const String _labelsUrl =
      'https://huggingface.co/k2-fsa/sherpa-onnx-ced-tiny-audio-tagging-2024-04-19/resolve/main/class_labels_indices.csv';

  bool _initialized = false;
  bool _downloading = false;
  String? _modelPath;
  String? _labelsPath;

  bool get isReady => _modelPath != null && _labelsPath != null;
  bool get isDownloading => _downloading;
  String? get modelPath => _modelPath;
  String? get labelsPath => _labelsPath;

  /// Only checks the local app-private cache. Never touches the network.
  Future<bool> initialize() async {
    if (_initialized) return isReady;
    try {
      final dir = await _getModelDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      final labelsFile = File('${dir.path}/$_labelsFileName');

      if (await modelFile.exists() && await labelsFile.exists()) {
        _modelPath = modelFile.path;
        _labelsPath = labelsFile.path;
      } else {
        debugPrint('AudioModelManager: local model is not installed');
      }

      _initialized = true;
      return isReady;
    } catch (e) {
      debugPrint('AudioModelManager local initialization error: $e');
      _initialized = true;
      return false;
    }
  }

  /// Explicit setup action. Monitoring must not call this method.
  Future<bool> downloadModel() async {
    if (isReady) return true;
    if (_downloading) return false;
    _downloading = true;
    try {
      final dir = await _getModelDirectory();
      if (!await _downloadFile(_modelUrl, '${dir.path}/$_modelFileName')) {
        return false;
      }
      if (!await _downloadFile(_labelsUrl, '${dir.path}/$_labelsFileName')) {
        // Never leave a model without its matching label file.
        final model = File('${dir.path}/$_modelFileName');
        if (await model.exists()) await model.delete();
        return false;
      }
      _modelPath = '${dir.path}/$_modelFileName';
      _labelsPath = '${dir.path}/$_labelsFileName';
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('AudioModelManager download error: $e');
      return false;
    } finally {
      _downloading = false;
    }
  }

  Future<bool> _downloadFile(String url, String targetPath) async {
    final partPath = '$targetPath.part';
    final partFile = File(partPath);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) return true;
    if (await partFile.exists()) await partFile.delete();

    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        if (response.statusCode != 200) return false;

        final sink = partFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
        }
        await sink.close();

        final stat = await partFile.stat();
        if (stat.size == 0) {
          await partFile.delete();
          return false;
        }
        await partFile.rename(targetPath);
        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('AudioModelManager file download error: $e');
      if (await partFile.exists()) await partFile.delete();
      return false;
    }
  }

  Future<Directory> _getModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/$_modelDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> deleteModel() async {
    try {
      final dir = await _getModelDirectory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _modelPath = null;
      _labelsPath = null;
      _initialized = false;
    } catch (e) {
      debugPrint('AudioModelManager delete error: $e');
    }
  }

  /// Backwards-compatible explicit setup helper. Never call from monitoring.
  Future<bool> ensureModelAvailable() async {
    if (await initialize()) return true;
    return downloadModel();
  }

  void dispose() {
    _modelPath = null;
    _labelsPath = null;
  }
}
