import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/conversation/services/mixed_transcript_parser.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('English preference preserves Urdu segment', () {
    final segments = MixedTranscriptParser.parse('Please open بازار', fallbackLanguage: 'English');
    expect(segments.map((s) => s.text).join(' '), contains('بازار'));
    expect(segments.any((s) => s.script == CaptionScript.arabic), isTrue);
  });
  test('Urdu preference preserves English segment', () {
    final segments = MixedTranscriptParser.parse('آج office جانا ہے', fallbackLanguage: 'Urdu');
    expect(segments.map((s) => s.text).join(' '), contains('office'));
    expect(segments.any((s) => s.script == CaptionScript.latin), isTrue);
  });
}
