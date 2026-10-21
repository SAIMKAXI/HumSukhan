import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:humsukhan/services/stt/model_manager.dart';

const _model = LanguageModel(
  id: 'test',
  name: 'Test',
  description: '',
  modelDir: 'test-model',
  kind: ModelKind.transducer,
  encoder: 'encoder.onnx',
  decoder: 'decoder.onnx',
  joiner: 'joiner.onnx',
  tokens: 'tokens.txt',
  fileBytes: {'encoder.onnx': 300000, 'decoder.onnx': 2000, 'joiner.onnx': 1000, 'tokens.txt': 10},
  sampleRate: 16000,
  sizeMB: 1,
  isStreaming: true,
  languages: ['English'],
  baseUrl: 'https://models.test/repo',
);

/// Serves each file of [_model] at its expected size, in 4 KB chunks.
class _Server extends http.BaseClient {
  final List<String> requested = [];

  /// Bytes to send for a file instead of its full size.
  final Map<String, int> truncate = {};
  int status = 200;
  Object? error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final name = request.url.pathSegments.last;
    requested.add(request.url.toString());
    final err = error;
    if (err != null) throw err;
    final size = truncate[name] ?? _model.fileBytes[name]!;
    Stream<List<int>> body() async* {
      for (var sent = 0; sent < size; sent += 4096) {
        yield List.filled((size - sent).clamp(0, 4096), 1);
      }
    }

    return http.StreamedResponse(body(), status);
  }
}

void main() {
  late Directory docs;
  late _Server server;
  late ModelManager manager;
  late List<ModelDownloadProgress> events;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('models');
    server = _Server();
    manager = ModelManager.test(documents: () async => docs, models: const {'English': _model});
    events = [];
    manager.onProgress.listen(events.add);
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<bool> download() => manager.downloadModel('English', client: () => server);

  test('the button downloads every file, reports byte progress, and leaves the model ready', () async {
    expect(manager.isModelReady('English'), isFalse);
    expect(await download(), isTrue);
    await pumpEventQueue();

    expect(server.requested, [
      'https://models.test/repo/encoder.onnx',
      'https://models.test/repo/decoder.onnx',
      'https://models.test/repo/joiner.onnx',
      'https://models.test/repo/tokens.txt',
    ]);
    expect(manager.isModelReady('English'), isTrue);
    expect(await manager.getModelPath('English'), '${docs.path}/sherpa_models/test-model');
    expect(File('${docs.path}/sherpa_models/test-model/encoder.onnx').lengthSync(), 300000);

    final progress = events.where((e) => e.status == DownloadStatus.downloading).map((e) => e.progress).toList();
    expect(progress.length, greaterThan(10), reason: 'the encoder alone should move the bar many times');
    expect(progress, orderedEquals([...progress]..sort()));
    expect(events.last.status, DownloadStatus.completed);
  });

  test('works without anything having initialized the manager first', () async {
    // Settings can be opened before any speech has started.
    expect(manager.statuses, isEmpty);
    expect(await download(), isTrue);
  });

  test('a cut-off file is not accepted as a model', () async {
    server.truncate['encoder.onnx'] = 120000;
    expect(await download(), isFalse);
    await pumpEventQueue();
    expect(manager.isModelReady('English'), isFalse);
    expect(manager.statuses['English']!.isDownloading, isFalse);
    expect(manager.lastError('English'), contains('incomplete'));
    expect(events.last.status, DownloadStatus.failed);
    expect(File('${docs.path}/sherpa_models/test-model/encoder.onnx').existsSync(), isFalse);
  });

  test('losing the connection is explained and the download can be retried', () async {
    server.error = const SocketException('Network is unreachable');
    expect(await download(), isFalse);
    expect(manager.lastError('English'), contains('internet connection'));

    server.error = null;
    expect(await download(), isTrue);
    expect(manager.lastError('English'), isNull);
  });

  test('a missing file on the server fails with its HTTP status', () async {
    server.status = 404;
    expect(await download(), isFalse);
    expect(manager.lastError('English'), contains('HTTP 404'));
  });

  test('files already downloaded are not fetched again', () async {
    server.truncate['joiner.onnx'] = 10;
    expect(await download(), isFalse);
    server.truncate.clear();
    server.requested.clear();
    expect(await download(), isTrue);
    expect(server.requested.map((u) => u.split('/').last), ['joiner.onnx', 'tokens.txt']);
  });

  test('a deleted model is no longer ready', () async {
    await download();
    expect(await manager.deleteModel('English'), isTrue);
    expect(manager.isModelReady('English'), isFalse);
    expect(await manager.getModelPath('English'), isNull);
  });

  test('the app offers a model for each caption language, at files the repositories have', () {
    for (final language in ['English', 'Urdu']) {
      final model = ModelManager.availableModels[language]!;
      expect(model.baseUrl, startsWith('https://huggingface.co/csukuangfj/'));
      expect(model.fileBytes.keys.toSet(), model.files.toSet(), reason: '$language: every file needs its size');
    }
    expect(ModelManager.availableModels['Urdu']!.whisperLanguage, 'ur');
  });
}
