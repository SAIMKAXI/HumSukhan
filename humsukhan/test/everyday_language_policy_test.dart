import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/everyday_language_policy.dart';

void main() {
  test('Urdu and Hindi scripts are distinguished', () {
    expect(EverydayLanguagePolicy.containsUrduScript('آپ کیسے ہیں؟'), isTrue);
    expect(EverydayLanguagePolicy.containsHindiScript('आप कैसे हैं?'), isTrue);
    expect(EverydayLanguagePolicy.containsHindiScript('آپ کیسے ہیں؟'), isFalse);
  });

  test('Hindi/Devanagari is removed from caption output', () {
    expect(
      EverydayLanguagePolicy.sanitizeHindi('Hello आप آپ'),
      'Hello آپ',
    );
    expect(EverydayLanguagePolicy.sanitizeHindi('आप کیسے ہیں'), 'کیسے ہیں');
    expect(EverydayLanguagePolicy.sanitizeHindi('आप'), isEmpty);
  });

  test('English mode preserves English and transliterates common Urdu', () {
    expect(
      EverydayLanguagePolicy.toEnglishMode('آپ کیسے ہیں؟'),
      'Aap kaise hain؟',
    );
    expect(
      EverydayLanguagePolicy.toEnglishMode('Hello آپ'),
      'Hello Aap',
    );
  });

  test('Roman Urdu is promoted to Urdu script only when a known mapping exists', () {
    expect(
      EverydayLanguagePolicy.normalizeRomanUrdu('aap kaise hain'),
      'آپ کیسے ہیں',
    );
    expect(
      EverydayLanguagePolicy.normalizeRomanUrdu('kal meeting hai at 5'),
      'کل meeting ہے at 5',
    );
    expect(
      EverydayLanguagePolicy.normalizeRomanUrdu('Hello world'),
      'Hello world',
    );
  });

  test('Hindi is never reintroduced by Roman Urdu normalization', () {
    final result = EverydayLanguagePolicy.normalizeRomanUrdu('आप aap');
    expect(result.contains('आप'), isFalse);
    expect(result, 'آپ');
  });

  test('legacy directional helper remains available for non-UI callers', () {
    final result = EverydayLanguagePolicy.withBidiIsolation('Hello آپ');
    expect(result, contains('\u2066Hello\u2069'));
    expect(result, contains('\u2067آپ\u2069'));
    expect(result.contains('आप'), isFalse);
  });
}
