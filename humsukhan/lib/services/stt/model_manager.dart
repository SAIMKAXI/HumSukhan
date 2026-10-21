import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages Sherpa-ONNX language models for offline speech recognition.
///
/// Only models whose output language is unambiguous for HumSukhan are exposed
/// here. A mixed-language recognizer is intentionally not accepted as an Urdu
/// fallback because its output cannot be constrained reliably at model level.
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager._();
  ModelManager._({
    Future<Directory> Function() documents = getApplicationDocumentsDirectory,
    Map<String, LanguageModel> models = availableModels,
  })  : _documents = documents,
        _models = models;

  /// A manager that keeps models under [documents], offering [models].
  @visibleForTesting
  factory ModelManager.test({
    required Future<Directory> Function() documents,
    Map<String, LanguageModel> models = availableModels,
  }) =>
      ModelManager._(documents: documents, models: models);

  final Future<Directory> Function() _documents;
  final Map<String, LanguageModel> _models;

  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();
  final Map<String, ModelStatus> _modelStatuses = {};
  bool _initialized = false;

  Stream<ModelDownloadProgress> get onProgress => _progressController.stream;
  Map<String, ModelStatus> get statuses => Map.unmodifiable(_modelStatuses);

  static const Map<String, LanguageModel> availableModels = {
    'English': LanguageModel(
      id: 'english_zipformer',
      name: 'English (Zipformer Streaming)',
      description: 'Real-time streaming speech recognition for English',
      modelDir: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
      kind: ModelKind.transducer,
      encoder: 'encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx',
      decoder: 'decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx',
      joiner: 'joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx',
      tokens: 'tokens.txt',
      fileBytes: {
        'encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx': 71082637,
        'decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx': 1307236,
        'joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx': 259335,
        'tokens.txt': 5048,
      },
      sampleRate: 16000,
      sizeMB: 73,
      isStreaming: true,
      languages: ['English'],
      baseUrl: 'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main',
    ),
    // Whisper is multilingual, but it is always run with its language fixed
    // to Urdu, so it cannot answer in another language or script.
    'Urdu': LanguageModel(
      id: 'urdu_whisper_base',
      name: 'Urdu (Whisper base)',
      description: 'Offline Urdu speech recognition, one sentence at a time',
      modelDir: 'sherpa-onnx-whisper-base',
      kind: ModelKind.whisper,
      encoder: 'base-encoder.int8.onnx',
      decoder: 'base-decoder.int8.onnx',
      tokens: 'base-tokens.txt',
      whisperLanguage: 'ur',
      fileBytes: {
        'base-encoder.int8.onnx': 29120534,
        'base-decoder.int8.onnx': 130672026,
        'base-tokens.txt': 816730,
      },
      sampleRate: 16000,
      sizeMB: 161,
      isStreaming: false,
      languages: ['Urdu'],
      baseUrl: 'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main',
    ),
  };

  final Map<String, String> _lastErrors = {};

  /// Why the last download of [language] failed, or null.
  String? lastError(String language) => _lastErrors[language];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final appDir = await _documents();
      final modelsDir = Directory('${appDir.path}/sherpa_models');

      for (final entry in _models.entries) {
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

  Future<bool> _verifyModelFiles(LanguageModel model, String dirPath) async {
    for (final file in model.files) {
      final f = File('$dirPath/$file');
      if (!await f.exists()) return false;
      final stat = await f.stat();
      if (stat.size == 0) return false;
    }
    return true;
  }

  Future<String?> getModelPath(String language) async {
    final status = _modelStatuses[language];
    if (status == null || !status.isDownloaded || status.localPath == null) {
      return null;
    }
    return status.localPath;
  }

  bool isModelReady(String language) {
    final status = _modelStatuses[language];
    return status?.isDownloaded == true && status?.localPath != null;
  }

  /// Downloads [language]'s model and returns whether it is ready to use.
  /// Progress, completion and failure are also reported on [onProgress].
  Future<bool> downloadModel(String language, {http.Client Function()? client}) async {
    await initialize();
    final model = _models[language];
    if (model == null) {
      _lastErrors[language] = 'No offline model is available for $language.';
      debugPrint(_lastErrors[language]);
      return false;
    }

    final status = _modelStatuses[language];
    if (status == null) {
      _lastErrors[language] = 'Offline models could not be prepared on this device.';
      return false;
    }
    if (status.isDownloaded) return true;
    if (status.isDownloading) return false;

    _lastErrors.remove(language);
    _modelStatuses[language] = status.copyWith(isDownloading: true, downloadProgress: 0.0);
    _progressController.add(ModelDownloadProgress(
      language: language,
      progress: 0.0,
      status: DownloadStatus.downloading,
    ));

    final httpClient = (client ?? http.Client.new)();
    try {
      final appDir = await _documents();
      final targetDir = Directory('${appDir.path}/sherpa_models/${model.modelDir}');
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final total = model.totalBytes;
      var done = 0;
      var reported = 0.0;
      void report(int bytes) {
        final progress = total == 0 ? 0.0 : (bytes / total).clamp(0.0, 0.99);
        // About every 1%, so a slow link still shows movement without
        // rebuilding the screen for every network packet.
        if (progress - reported < 0.01) return;
        reported = progress;
        _modelStatuses[language] = _modelStatuses[language]!.copyWith(downloadProgress: progress);
        _progressController.add(ModelDownloadProgress(
          language: language,
          progress: progress,
          status: DownloadStatus.downloading,
        ));
      }

      for (final fileName in model.files) {
        final targetFile = File('${targetDir.path}/$fileName');
        final expected = model.fileBytes[fileName];
        if (await targetFile.exists()) {
          final size = await targetFile.length();
          if (size > 0 && (expected == null || size == expected)) {
            done += size;
            report(done);
            continue;
          }
        }

        debugPrint('Downloading $fileName for $language...');
        final streamed = await httpClient
            .send(http.Request('GET', Uri.parse('${model.baseUrl}/$fileName')))
            .timeout(const Duration(seconds: 30));
        if (streamed.statusCode != 200) {
          throw Exception('Failed to download $fileName: HTTP ${streamed.statusCode}');
        }

        final partFile = File('${targetFile.path}.part');
        if (await partFile.exists()) await partFile.delete();
        final sink = partFile.openWrite();
        var bytesWritten = 0;
        try {
          // A stalled connection fails instead of hanging the button forever.
          await for (final chunk in streamed.stream.timeout(const Duration(seconds: 60))) {
            sink.add(chunk);
            bytesWritten += chunk.length;
            report(done + bytesWritten);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (bytesWritten == 0 || (expected != null && bytesWritten != expected)) {
          if (await partFile.exists()) await partFile.delete();
          throw Exception('Download of $fileName was incomplete ($bytesWritten bytes)');
        }

        if (await targetFile.exists()) await targetFile.delete();
        await partFile.rename(targetFile.path);
        done += bytesWritten;
      }

      if (!await _verifyModelFiles(model, targetDir.path)) {
        throw Exception('Downloaded files verification failed');
      }

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
      return true;
    } catch (e) {
      debugPrint('Model download failed for $language: $e');
      _lastErrors[language] = e is SocketException || e is TimeoutException || e is http.ClientException
          ? 'The download was interrupted. Check your internet connection and try again.'
          : 'The download failed: $e';
      _modelStatuses[language] = _modelStatuses[language]!.copyWith(
        isDownloading: false,
        downloadProgress: 0.0,
      );
      _progressController.add(ModelDownloadProgress(
        language: language,
        progress: 0.0,
        status: DownloadStatus.failed,
        error: _lastErrors[language],
      ));
      return false;
    } finally {
      httpClient.close();
    }
  }

  Future<bool> deleteModel(String language) async {
    final status = _modelStatuses[language];
    if (status == null || !status.isDownloaded || status.localPath == null) return false;

    try {
      final dir = Directory(status.localPath!);
      if (await dir.exists()) await dir.delete(recursive: true);
      _modelStatuses[language] = ModelStatus(
        model: status.model,
        isDownloaded: false,
        isDownloading: false,
        downloadProgress: 0.0,
      );
      _progressController.add(ModelDownloadProgress(language: language, progress: 0.0, status: DownloadStatus.deleted));
      return true;
    } catch (e) {
      debugPrint('Failed to delete model for $language: $e');
      return false;
    }
  }

  LanguageModel? getBestModel(String language) {
    for (final model in _models.values) {
      if (model.languages.contains(language) && model.isStreaming && isModelReady(language)) {
        return model;
      }
    }
    for (final model in _models.values) {
      if (model.languages.contains(language) && isModelReady(language)) return model;
    }
    return null;
  }

  List<String> get availableLanguages => _models.keys.toList();

  List<String> get readyLanguages =>
      _modelStatuses.entries.where((e) => e.value.isDownloaded).map((e) => e.key).toList();

  void dispose() {
    _progressController.close();
  }
}

enum ModelKind { transducer, whisper }

class LanguageModel {
  final String id;
  final String name;
  final String description;
  final String modelDir;
  final ModelKind kind;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  /// The language a [ModelKind.whisper] model is held to.
  final String whisperLanguage;

  /// Expected size of each file, so a cut-off download is caught and the
  /// progress bar measures bytes rather than files.
  final Map<String, int> fileBytes;
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
    required this.kind,
    this.encoder = '',
    this.decoder = '',
    this.joiner = '',
    required this.tokens,
    this.whisperLanguage = '',
    this.fileBytes = const {},
    required this.sampleRate,
    required this.sizeMB,
    required this.isStreaming,
    required this.languages,
    required this.baseUrl,
  });

  List<String> get files => [
        for (final f in [encoder, decoder, joiner, tokens])
          if (f.isNotEmpty) f,
      ];

  int get totalBytes => fileBytes.values.fold(0, (a, b) => a + b);

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
  deleted,
}
