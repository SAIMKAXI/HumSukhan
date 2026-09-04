import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings no longer exposes retired Caption Language control', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(source, isNot(contains('captionLanguage')));
    expect(source, isNot(contains('_showLanguageDialog')));
  });

  test('everyday input is bilingual and script aware', () {
    final source = File('lib/screens/everyday_screen.dart').readAsStringSync();
    expect(source, contains('containsUrduScript'));
    expect(source, contains('TextDirection.rtl'));
    expect(source, contains('NotoNastaliqUrdu'));
    expect(source, contains('Type in Urdu or English'));
  });
}
