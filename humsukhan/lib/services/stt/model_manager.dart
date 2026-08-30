import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages Sherpa-ONNX language models for offline speech recognition.
///
/// Models are downloaded as individual files from HuggingFace (no archive
/// extraction needed). Each language requires specific .onnx and .txt files.
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager._();
  ModelManager._();

  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();
  final Map<String, ModelStatus> _modelStatuses = {};
  bool _initialized = false;

  Stream<ModelDownloadProgress> get onProgress => _progressController.stream;
  Map<String, ModelStatus> get statuses => Map.unmodifiable(_modelStatuses);

  /// Available models for the app with individual file download URLs.
  static const Map<String, LanguageModel> availableModels = {
    'English': LanguageModel(
      id: 'english_zipformer',
      name: 'English (Zipformer Streaming)',
      description: 'Real-time streaming speech recognition for English',
      modelDir: 'sherpa-onnx-streaming-zipformer-bilingual-en-zh-2023-02-20',
      encoder: 'encoder-epoch-99-avg-1-chunk-16-left-64.onnx',
      decoder: 'decoder-epoch-99-avg-1-chunk-16-left-64.onnx',
      joiner: 'joiner-epoch-99-avg-1-chunk-16-left-64.onnx',
      tokens: 'tokens.txt',
      sampleRate: 16000,
      sizeMB: 80,
      isStreaming: true,
      languages: ['English'],
      baseUrl: 'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-en-zh-2023-02-20/resolve/main',
    ),
    'Urdu': LanguageModel(
      id: 'urdu_dolphin',
      name: 'Urdu/Hindi (Dolphin CTC)',
      description: 'Offline speech recognition for Urdu and Hindi',
      modelDir: 'sherpa-onnx-dolphin-small-ctc-multi-lang-2025-04-02',
      encoder: '',
      decoder: '',
      joiner: '',
      tokens: 'tokens.txt',
      modelFile: 'model.int8.onnx',
      sampleRate: 16000,
      sizeMB: 239,
      isStreaming: false,
      languages: ['Urdu', 'Hindi'],
      baseUrl: 'https://huggingface.co/csukuangfj/sherpa-onnx-dolphin-small-ctc-multi-lang-int8-2025-04-02/resolve/main',
    ),
  };

  /// Initialize the model manager and check which models are downloaded.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/sherpa_models');

      for (final entry in availableModels.entries) {
        final modelDir = Directory('${modelsDir.path}/${entry.value.modelDir}');
        final isDownloaded = await _verifyModelFiles(entry.value, modelDir.path);

        _modelStatuses[entry.key] = ModelStatus(
          model: entry.value,
          isDownloaded: isDownloaded,
          isDownloading: false,
          downloadProgress: isDownloaded ? 1.0 : 0.0,
          localPath: isDownloaded ? modelDir.path : null,
        );
      }

      _initialized = true;
      debugPrint('ModelManager initialized. Downloaded models: '
          '${_modelStatuses.entries.where((e) => e.value.isDownloaded).map((e) => e.key).toList()}');
    } catch (e) {
      debugPrint('ModelManager initialization failed: $e');
    }
  }

  /// Verify that all required model files exist and are non-empty.
  Future<bool> _verifyModelFiles(LanguageModel model, String dirPath) async {
    final requiredFiles = <String>[model.tokens];
    if (model.isStreaming) {
      requiredFiles.addAll([model.encoder, model.decoder, model.joiner]);
    } else if (model.modelFile != null) {
      requiredFiles.add(model.modelFile!);
    }

    for (final file in requiredFiles) {
      final f = File('$dirPath/$file');
      if (!await f.exists()) return false;
      final stat = await f.stat();
      if (stat.size == 0) return false;
    }
    return true;
  }

  /// Get the local path for a downloaded model.
  Future<String?> getModelPath(String language) async {
    final status = _modelStatuses[language];
    if (status == null || !status.isDownloaded || status.localPath == null) {
      return null;
    }
    return status.localPath;
  }

  /// Check if a model is downloaded and ready to use.
  bool isModelReady(String language) {
    final status = _modelStatuses[language];
    return status?.isDownloaded == true && status?.localPath != null;
  }

  /// Download individual model files for the specified language.
  Future<bool> downloadModel(String language) async {
    final model = availableModels[language];
    if (model == null) {
      debugPrint('No model available for $language');
      return false;
    }

    final status = _modelStatuses[language];
    if (status == null || status.isDownloaded || status.isDownloading) {
      return false;
    }

    // Mark as downloading
    _modelStatuses[language] = status.copyWith(isDownloading: true, downloadProgress: 0.0);
    _progressController.add(ModelDownloadProgress(
      language: language,
      progress: 0.0,
      status: DownloadStatus.downloading,
    ));

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/sherpa_models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final targetDir = Directory('${modelsDir.path}/${model.modelDir}');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Collect all files to download
      final filesToDownload = <String>[model.tokens];
      if (model.isStreaming) {
        filesToDownload.addAll([model.encoder, model.decoder, model.joiner]);
      } else if (model.modelFile != null) {
        filesToDownload.add(model.modelFile!);
      }

      // Download each file individually
      final client = http.Client();
      try {
        for (int i = 0; i < filesToDownload.length; i++) {
          final fileName = filesToDownload[i];
          final fileUrl = '${model.baseUrl}/$fileName';
          final targetFile = File('${targetDir.path}/$fileName');

          // Skip if already exists
          if (await targetFile.exists()) {
            final stat = await targetFile.stat();
            if (stat.size > 0) continue;
          }

          debugPrint('Downloading $fileName for $language...');
          final response = await client.get(Uri.parse(fileUrl));

          if (response.statusCode != 200) {
            throw Exception('Failed to download $fileName: HTTP ${response.statusCode}');
          }

          // Write to .part file, then rename for atomicity
          final partFile = File('${targetFile.path}.part');
          await partFile.writeAsBytes(response.bodyBytes);
          await partFile.rename(targetFile.path);

          final progress = (i + 1) / filesToDownload.length;
          _progressController.add(ModelDownloadProgress(
            language: language,
            progress: progress,
            status: DownloadStatus.downloading,
          ));
          _modelStatuses[language] = _modelStatuses[language]!.copyWith(
            downloadProgress: progress,
          );
        }
      } finally {
        client.close();
      }

      // Verify all files are present
      if (!await _verifyModelFiles(model, targetDir.path)) {
        throw Exception('Downloaded files verification failed');
      }

      // Mark as downloaded
      _modelStatuses[language] = ModelStatus(
        model: model,
        isDownloaded: true,
        isDownloading: false,
        downloadProgress: 1.0,
        localPath: targetDir.path,
      );

      _progressController.add(ModelDownloadProgress(
        language: language,
        progress: 1.0,
        status: DownloadStatus.completed,
      ));

      debugPrint('Model download completed for $language');
      return true;
    } catch (e) {
      debugPrint('Model download failed for $language: $e');

      _modelStatuses[language] = _modelStatuses[language]!.copyWith(
        isDownloading: false,
        downloadProgress: 0.0,
      );

      _progressController.add(ModelDownloadProgress(
        language: language,
        progress: 0.0,
        status: DownloadStatus.failed,
        error: e.toString(),
      ));

      return false;
    }
  }

  /// Delete a downloaded model to free up space.
  Future<bool> deleteModel(String language) async {
    final status = _modelStatuses[language];
    if (status == null || !status.isDownloaded || status.localPath == null) {
      return false;
    }

    try {
      final dir = Directory(status.localPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      _modelStatuses[language] = status.copyWith(
        isDownloaded: false,
        localPath: null,
        downloadProgress: 0.0,
      );

      debugPrint('Model deleted for $language');
      return true;
    } catch (e) {
      debugPrint('Failed to delete model for $language: $e');
      return false;
    }
  }

  /// Get the best model for a given language.
  LanguageModel? getBestModel(String language) {
    for (final model in availableModels.values) {
      if (model.languages.contains(language) && model.isStreaming) {
        if (isModelReady(language)) return model;
      }
    }
    for (final model in availableModels.values) {
      if (model.languages.contains(language)) {
        if (isModelReady(language)) return model;
      }
    }
    return null;
  }

  List<String> get availableLanguages => availableModels.keys.toList();

  List<String> get readyLanguages =>
      _modelStatuses.entries.where((e) => e.value.isDownloaded).map((e) => e.key).toList();

  void dispose() {
    _progressController.close();
  }
}

class LanguageModel {
  final String id;
  final String name;
  final String description;
  final String modelDir;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final String? modelFile;
  final int sampleRate;
  final int sizeMB;
  final bool isStreaming;
  final List<String> languages;
  final String baseUrl;

  const LanguageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.modelDir,
    this.encoder = '',
    this.decoder = '',
    this.joiner = '',
    required this.tokens,
    this.modelFile,
    required this.sampleRate,
    required this.sizeMB,
    required this.isStreaming,
    required this.languages,
    required this.baseUrl,
  });

  String get sizeLabel => '$sizeMB MB';
}

class ModelStatus {
  final LanguageModel model;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final String? localPath;

  const ModelStatus({
    required this.model,
    required this.isDownloaded,
    required this.isDownloading,
    required this.downloadProgress,
    this.localPath,
  });

  ModelStatus copyWith({
    bool? isDownloaded,
    bool? isDownloading,
    double? downloadProgress,
    String? localPath,
  }) {
    return ModelStatus(
      model: model,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
    );
  }

  String get statusLabel {
    if (isDownloaded) return 'Ready';
    if (isDownloading) return 'Downloading ${(downloadProgress * 100).toInt()}%';
    return 'Not downloaded';
  }
}

class ModelDownloadProgress {
  final String language;
  final double progress;
  final DownloadStatus status;
  final String? error;

  const ModelDownloadProgress({
    required this.language,
    required this.progress,
    required this.status,
    this.error,
  });
}

enum DownloadStatus {
  downloading,
  completed,
  failed,
}
