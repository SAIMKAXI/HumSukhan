import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/l10n/app_messages.dart';
import 'package:humsukhan/l10n/app_strings.dart';

/// Every status and error sentence written outside the widget tree has an
/// Urdu translation, so the Urdu interface never shows one in English.
void main() {
  /// Sources whose messages reach the screen through [AppStrings.message].
  const sources = [
    'lib/services/conversation_engine.dart',
    'lib/providers/conversation_provider.dart',
    'lib/providers/connectivity_provider.dart',
    'lib/providers/everyday_speech_provider.dart',
    'lib/services/everyday_bilingual_stt.dart',
    'lib/services/stt/enhanced_stt.dart',
    'lib/providers/professional_provider.dart',
    'lib/services/auth_service.dart',
    'lib/providers/auth_provider.dart',
    'lib/screens/session_live_screen.dart',
  ];

  /// Values that look like sentences but are stored, not shown.
  const notMessages = {'Speaker 1', 'Roman Urdu'};

  /// Sentences in single quotes, with neighbouring literals joined, outside
  /// logging and exceptions.
  List<String> sentences(String source) {
    final lines = source.split('\n').where((line) => !RegExp(r'debugPrint|print\(|ArgumentError|StateError|Exception\(').hasMatch(line));
    final joined = lines.join('\n').replaceAll(RegExp(r"'\s*\n\s*'"), '');
    return [
      for (final match in RegExp(r"'((?:\\.|[^'\\])*)'").allMatches(joined))
        if (RegExp(r'^[A-Z]').hasMatch(match[1]!) && match[1]!.contains(' ') && !notMessages.contains(match[1])) match[1]!,
    ];
  }

  /// Fills `$name` placeholders the way the app does at run time.
  String fill(String message) => message.replaceAllMapped(RegExp(r'\$\{[^}]*\}|\$\w+'), (m) {
        final name = m[0]!.toLowerCase();
        if (name.contains('length') || name.contains('second')) return '8';
        if (name.contains('language')) return 'Urdu';
        return 'x';
      });

  test('every message from the app has Urdu', () {
    final missing = <String>[];
    for (final path in sources) {
      for (final message in sentences(File(path).readAsStringSync())) {
        if (urduMessage(fill(message)) == null) missing.add('$path: $message');
      }
    }
    expect(missing, isEmpty, reason: 'Add these to lib/l10n/app_messages.dart:\n${missing.join('\n')}');
  });

  test('every message from the account service has Urdu', () {
    final source = File('../supabase/functions/create-account/index.ts').readAsStringSync();
    final messages = [
      for (final match in RegExp(r"HttpError\(\s*\d+,\s*['`]([^'`]+)['`]", multiLine: true).allMatches(source)) fill(match[1]!),
    ];
    expect(messages, isNotEmpty);
    expect([for (final m in messages) if (urduMessage(m) == null) m], isEmpty);
  });

  test('messages pass through in English and are translated in Urdu', () {
    final en = AppStrings(const Locale('en'));
    final ur = AppStrings(const Locale('ur'));
    expect(en.message('Checking...'), 'Checking...');
    expect(ur.message('Checking...'), 'جانچ ہو رہی ہے…');
    expect(ur.message('Password must be 8 to 72 characters.'), 'پاس ورڈ 8 سے 72 حروف کا ہونا چاہیے۔');
    expect(ur.message('Speech recognition connection failed: SocketException'), contains('آواز کی پہچان'));
    expect(ur.message('No internet connection, and no offline speech model is downloaded for Urdu. Download one in Settings to caption without a connection.'), contains('اردو'));
  });

  test('an unknown English message becomes a general Urdu one, never English', () {
    final ur = AppStrings(const Locale('ur'));
    expect(ur.message('Something new went wrong'), urduGeneralError);
    expect(ur.message('پہلے سے اردو'), 'پہلے سے اردو');
  });

  test('stored speaker names and languages are shown in Urdu', () {
    final ur = AppStrings(const Locale('ur'));
    expect(ur.speakerName('Speaker 1'), 'بولنے والا 1');
    expect(ur.speakerName('You'), 'آپ');
    expect(ur.languageName('English'), 'انگریزی');
    expect(ur.displayName('User'), 'صارف');
    expect(AppStrings(const Locale('en')).speakerName('Speaker 1'), 'Speaker 1');
  });
}
