import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages the sherpa-onnx CED-mini audio tagging model.
///
/// Downloads model + labels on first activation, then operates completely offline.
/// Uses .part files during download to prevent corrupt models from interrupted downloads.
class AudioModelManager {
  static AudioModelManager? _instance;
  static AudioModelManager get instance => _instance ??= AudioModelManager._();
  AudioModelManager._();

  static const String _modelFileName = 'model.int8.onnx';
  static const String _labelsFileName = 'class_labels_indices.csv';
  static const String _modelDirName = 'sherpa_ced_mini';

  // HuggingFace raw file URLs for k2-fsa/sherpa-onnx-ced-mini-audio-tagging-2024-04-19
  static const String _modelUrl =
      'https://huggingface.co/k2-fsa/sherpa-onnx-ced-mini-audio-tagging-2024-04-19/resolve/main/model.int8.onnx';
  static const String _labelsUrl =
      'https://huggingface.co/k2-fsa/sherpa-onnx-ced-mini-audio-tagging-2024-04-19/resolve/main/class_labels_indices.csv';

  bool _initialized = false;
  bool _downloading = false;
  String? _modelPath;
  String? _labelsPath;

  bool get isReady => _modelPath != null && _labelsPath != null;
  bool get isDownloading => _downloading;
  String? get modelPath => _modelPath;
  String? get labelsPath => _labelsPath;

  /// Initialize and check if model already exists locally.
  Future<bool> initialize() async {
    if (_initialized) return isReady;

    try {
      final dir = await _getModelDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      final labelsFile = File('${dir.path}/$_labelsFileName');

      if (await modelFile.exists() && await labelsFile.exists()) {
        _modelPath = modelFile.path;
        _labelsPath = labelsFile.path;
        debugPrint('AudioModelManager: Model already cached at ${dir.path}');
      } else {
        debugPrint('AudioModelManager: Model not found locally');
      }

      _initialized = true;
      return isReady;
    } catch (e) {
      debugPrint('AudioModelManager init error: $e');
      _initialized = true;
      return false;
    }
  }

  /// Download model and labels. Returns true on success.
  /// Uses .part files so interrupted downloads cannot leave corrupt models.
  Future<bool> downloadModel() async {
    if (isReady) return true;
    if (_downloading) return false;
    _downloading = true;

    try {
      final dir = await _getModelDirectory();

      // Download model file
      if (!await _downloadFile(_modelUrl, '${dir.path}/$_modelFileName')) {
        return false;
      }

      // Download labels file
      if (!await _downloadFile(_labelsUrl, '${dir.path}/$_labelsFileName')) {
        return false;
      }

      _modelPath = '${dir.path}/$_modelFileName';
      _labelsPath = '${dir.path}/$_labelsFileName';

      debugPrint('AudioModelManager: Download complete. Model: $_modelPath');
      return true;
    } catch (e) {
      debugPrint('AudioModelManager download error: $e');
      return false;
    } finally {
      _downloading = false;
    }
  }

  /// Download a single file with .part intermediate to prevent corruption.
  Future<bool> _downloadFile(String url, String targetPath) async {
    final partPath = '$targetPath.part';
    final partFile = File(partPath);
    final targetFile = File(targetPath);

    // If target already exists, skip
    if (await targetFile.exists()) {
      return true;
    }

    // Clean up any leftover .part file
    if (await partFile.exists()) {
      await partFile.delete();
    }

    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          debugPrint('AudioModelManager: Download failed with status ${response.statusCode}');
          return false;
        }

        // Write to .part file first
        final sink = partFile.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
        }
        await sink.close();

        // Verify .part file is not empty
        final partStat = await partFile.stat();
        if (partStat.size == 0) {
          await partFile.delete();
          return false;
        }

        // Atomically rename .part to target
        await partFile.rename(targetPath);
        debugPrint('AudioModelManager: Downloaded ${targetPath.split('/').last} (${partStat.size} bytes)');
        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('AudioModelManager: File download error: $e');
      // Clean up .part file on failure
      if (await partFile.exists()) {
        await partFile.delete();
      }
      return false;
    }
  }

  /// Get or create the model directory.
  Future<Directory> _getModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/$_modelDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Delete cached model to free space.
  Future<void> deleteModel() async {
    try {
      final dir = await _getModelDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _modelPath = null;
      _labelsPath = null;
      _initialized = false;
      debugPrint('AudioModelManager: Model deleted');
    } catch (e) {
      debugPrint('AudioModelManager: Delete error: $e');
    }
  }

  /// Ensure model is available. Downloads if necessary.
  /// Returns true if model is ready after this call.
  Future<bool> ensureModelAvailable() async {
    if (!await initialize()) {
      return await downloadModel();
    }
    return isReady;
  }

  void dispose() {
    _modelPath = null;
    _labelsPath = null;
  }
}
