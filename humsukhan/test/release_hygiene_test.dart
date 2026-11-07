import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the app keeps off the phone's backups and logs. The built APK itself
/// is checked in CI by tool/check_apk.py.
void main() {
  test('nothing goes into Android backup or transfer to a new phone', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(rules)!.group(1)!;
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(body, contains('<exclude domain="$domain" path="." />'), reason: '$section keeps $domain');
      }
    }
  });

  test('release builds write nothing to the system log', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(RegExp(r'silenceLogsInRelease\(\);').allMatches(main), hasLength(2),
        reason: 'both the app and the background alert engine start silenced');
  });

  test('no unused icon font is bundled', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('cupertino_icons')));
  });
}
