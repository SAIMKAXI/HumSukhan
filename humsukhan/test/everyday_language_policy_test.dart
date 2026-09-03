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

  test('mixed captions receive directional isolation marks', () {
    final result = EverydayLanguagePolicy.withBidiIsolation('Hello آپ');
    expect(result, contains('\u2066Hello\u2069'));
    expect(result, contains('\u2067آپ\u2069'));
    expect(result.contains('आप'), isFalse);
  });
}
