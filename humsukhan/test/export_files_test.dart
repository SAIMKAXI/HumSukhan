import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/export_files.dart';

/// A shared transcript does not stay in the app's storage past its retention
/// period: exports live in the cache and are cleared by the next export or
/// the next start of the app.
void main() {
  late Directory root;
  late Directory cache;
  late Directory documents;

  setUp(() {
    root = Directory.systemTemp.createTempSync('exports_test');
    cache = Directory('${root.path}/cache')..createSync();
    documents = Directory('${root.path}/documents')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('an export goes to the cache and replaces the previous one', () async {
    final first = await ExportFiles.create('humsukhan_a.txt', cache: () async => cache);
    await first.writeAsString('first transcript');
    final second = await ExportFiles.create('humsukhan_b.txt', cache: () async => cache);
    await second.writeAsString('second transcript');

    expect(second.path, startsWith('${cache.path}/${ExportFiles.folder}/'));
    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
  });

  test('clean-up removes exports and only exports', () async {
    final export = await ExportFiles.create('humsukhan_a.txt', cache: () async => cache);
    await export.writeAsString('transcript');
    final legacy = File('${documents.path}/humsukhan_old-session.txt')..writeAsStringSync('old transcript');
    final model = File('${documents.path}/models/urdu/model.onnx')..createSync(recursive: true);
    final other = File('${documents.path}/notes.txt')..writeAsStringSync('keep');

    await ExportFiles.cleanUp(cache: () async => cache, documents: () async => documents);

    expect(export.existsSync(), isFalse);
    expect(legacy.existsSync(), isFalse);
    expect(model.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
  });

  test('clean-up never throws', () async {
    await ExportFiles.cleanUp(
      cache: () async => throw const FileSystemException('unavailable'),
      documents: () async => documents,
    );
  });
}
