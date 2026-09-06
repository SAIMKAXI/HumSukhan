import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Installs and manages the bundled sherpa-onnx CED-Tiny audio tagging model.
///
/// The model ships inside the application package. Runtime monitoring never
/// performs a network request and never asks the user to visit another site or
/// complete a separate model setup step.
class AudioModelManager {
  static AudioModelManager? _instance;
  static AudioModelManager get instance => _instance ??= AudioModelManager._();
  AudioModelManager._();

  static const String _modelFileName = 'model.int8.onnx';
  static const String _labelsFileName = 'class_labels_indices.csv';
  static const String _modelDirName = 'sherpa_ced_tiny';
  static const String _modelAsset = 'assets/environmental/model.int8.onnx';
  static const String _labelsAsset = 'assets/environmental/class_labels_indices.csv';

  bool _initialized = false;
  bool _installing = false;
  String? _modelPath;
  String? _labelsPath;

  bool get isReady => _modelPath != null && _labelsPath != null;
  bool get isDownloading => _installing;
  String? get modelPath => _modelPath;
  String? get labelsPath => _labelsPath;

  /// Ensures the app-private model files exist by copying them from the APK.
  /// No network access is used here.
  Future<bool> initialize() async {
    if (_initialized) return isReady;
    if (_installing) return false;
    _installing = true;
    try {
      final dir = await _getModelDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');
      final labelsFile = File('${dir.path}/$_labelsFileName');

      if (!await modelFile.exists() || !await labelsFile.exists()) {
        await _copyBundledFile(_modelAsset, modelFile);
        await _copyBundledFile(_labelsAsset, labelsFile);
      }

      if (await modelFile.exists() && await labelsFile.exists()) {
        _modelPath = modelFile.path;
        _labelsPath = labelsFile.path;
      } else {
        debugPrint('AudioModelManager: bundled environmental model is unavailable');
      }

      _initialized = true;
      return isReady;
    } catch (e) {
      debugPrint('AudioModelManager bundled model initialization error: $e');
      _initialized = true;
      return false;
    } finally {
      _installing = false;
    }
  }

  Future<void> _copyBundledFile(String assetPath, File target) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();
    await part.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  }

  /// Kept for source compatibility with older callers. The model is bundled,
  /// so there is no runtime download or external setup anymore.
  Future<bool> downloadModel() => initialize();

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

  Future<bool> ensureModelAvailable() => initialize();

  void dispose() {
    _modelPath = null;
    _labelsPath = null;
    _initialized = false;
  }
}
