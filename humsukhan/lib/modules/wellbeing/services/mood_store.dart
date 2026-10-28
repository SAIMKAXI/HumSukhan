import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/mood_entry.dart';

/// What [MoodStore.load] found.
@immutable
class MoodLoad {
  const MoodLoad(this.entries, {this.damaged = false});

  /// Oldest first.
  final List<MoodEntry> entries;

  /// The file, or some records in it, could not be read. A damaged file is
  /// set aside rather than overwritten, so nothing is silently lost.
  final bool damaged;
}

/// Keeps one account's check-ins in a file on this phone.
///
/// Check-ins are never sent to the server. The `wellbeing/` folder is also
/// excluded from Android's cloud backup and device-to-device transfer (see
/// `res/xml/backup_rules.xml` and `res/xml/data_extraction_rules.xml`), so
/// they stay on this phone only.
class MoodStore {
  MoodStore({required String account, Future<Directory> Function()? baseDirectory})
      : _account = _safeName(account),
        _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  /// Folder under the app's private files directory. Must match the backup
  /// exclusion rules.
  static const String folder = 'wellbeing';

  /// Check-ins older than this are dropped when the file is next written.
  static const Duration keepFor = Duration(days: 400);

  final String _account;
  final Future<Directory> Function() _baseDirectory;
  Future<void> _writes = Future<void>.value();

  static String _safeName(String account) {
    final cleaned = account.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'guest' : cleaned;
  }

  Future<File> _file() async {
    final base = await _baseDirectory();
    final dir = Directory('${base.path}/$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$_account.json');
  }

  Future<MoodLoad> load() async {
    final file = await _file();
    if (!await file.exists()) return const MoodLoad([]);
    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      debugPrint('Wellbeing check-ins could not be read: $e');
      return const MoodLoad([], damaged: true);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      debugPrint('Wellbeing check-ins file is damaged: $e');
      await _setAside(file);
      return const MoodLoad([], damaged: true);
    }
    final records = decoded is Map ? decoded['entries'] : null;
    if (records is! List) {
      await _setAside(file);
      return const MoodLoad([], damaged: true);
    }
    final entries = <MoodEntry>[];
    var damaged = false;
    for (final record in records) {
      final entry = MoodEntry.tryFromJson(record);
      if (entry == null) {
        damaged = true;
      } else {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    return MoodLoad(entries, damaged: damaged);
  }

  /// Replaces the saved check-ins with [entries]. Writes go one at a time,
  /// to a temporary file that then replaces the old one, so a crash part way
  /// through never leaves a half-written file.
  Future<void> save(List<MoodEntry> entries, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(keepFor);
    final kept = [for (final e in entries) if (e.at.isAfter(cutoff)) e];
    final write = _writes.then((_) async {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({'version': 1, 'entries': [for (final e in kept) e.toJson()]}),
        flush: true,
      );
      await temp.rename(file.path);
    });
    // The caller gets the error; the queue itself carries on.
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  /// Removes every saved check-in for this account, including any damaged
  /// copies set aside earlier.
  Future<void> deleteAll() {
    final delete = _writes.then((_) async {
      final file = await _file();
      final dir = file.parent;
      await for (final item in dir.list()) {
        if (item is File && item.uri.pathSegments.last.startsWith('$_account.json')) {
          await item.delete();
        }
      }
    });
    _writes = delete.then<void>((_) {}, onError: (Object _) {});
    return delete;
  }

  Future<void> _setAside(File file) async {
    try {
      await file.rename('${file.path}.damaged-${DateTime.now().millisecondsSinceEpoch}');
    } on FileSystemException catch (e) {
      debugPrint('Damaged wellbeing file could not be set aside: $e');
    }
  }
}
