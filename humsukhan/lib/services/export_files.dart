import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Where session exports are written before they are shared.
///
/// An export holds a whole transcript, which the app deletes when its
/// retention period ends. So exports go to the cache, never to the app's
/// permanent storage, and each one is removed by the next export or the next
/// start of the app. It is not removed as soon as the share sheet closes,
/// because the app it was shared to may still be reading it.
class ExportFiles {
  ExportFiles._();

  static const folder = 'exports';

  /// Exports older versions of the app left in permanent storage.
  static final _legacyExport = RegExp(r'^humsukhan_.+\.txt$');

  /// A new file named [name] for an export. Earlier exports are deleted.
  static Future<File> create(String name, {Future<Directory> Function() cache = getTemporaryDirectory}) async {
    final directory = Directory('${(await cache()).path}/$folder');
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    return File('${directory.path}/$name');
  }

  /// Deletes every export left behind, in the cache and, from older versions
  /// of the app, in permanent storage. Never throws.
  static Future<void> cleanUp({
    Future<Directory> Function() cache = getTemporaryDirectory,
    Future<Directory> Function() documents = getApplicationDocumentsDirectory,
  }) async {
    try {
      final exports = Directory('${(await cache()).path}/$folder');
      if (await exports.exists()) await exports.delete(recursive: true);
      final permanent = await documents();
      if (!await permanent.exists()) return;
      await for (final entity in permanent.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && _legacyExport.hasMatch(name)) await entity.delete();
      }
    } catch (e) {
      debugPrint('Old exports could not be removed: $e');
    }
  }
}
