import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/conversation/services/mixed_transcript_parser.dart';

void main() {
  test('preferred language is not a transcript filter', () {
    final english = MixedTranscriptParser.parse('hello بازار', fallbackLanguage: 'English');
    final urdu = MixedTranscriptParser.parse('hello بازار', fallbackLanguage: 'Urdu');
    expect(english.map((x) => x.text).join(' '), contains('بازار'));
    expect(urdu.map((x) => x.text).join(' '), contains('hello'));
  });
}
