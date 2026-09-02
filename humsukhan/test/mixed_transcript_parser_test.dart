import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/conversation/services/mixed_transcript_parser.dart';

void main() {
  group('MixedTranscriptParser', () {
    test('splits contiguous English and Urdu without translating content', () {
      final result = MixedTranscriptParser.parse(
        'I am going to بازار and then coming home.',
      );

      expect(result.map((s) => s.text).toList(), [
        'I am going to',
        'بازار',
        'and then coming home.',
      ]);
      expect(result.map((s) => s.script).toList(), [
        CaptionScript.latin,
        CaptionScript.arabic,
        CaptionScript.latin,
      ]);
      expect(result.map((s) => s.language).toList(), [
        'English',
        'Urdu',
        'English',
      ]);
    });

    test('detects Devanagari but does not silently transliterate it', () {
      final result = MixedTranscriptParser.parse(
        'I said बाज़ार today.',
      );

      expect(result.any((s) => s.script == CaptionScript.devanagari), isTrue);
      expect(result.map((s) => s.text).join(' '), contains('बाज़ार'));
    });

    test('preserves Roman Urdu fallback for Latin-script segments', () {
      final result = MixedTranscriptParser.parse(
        'main theek hoon',
        fallbackLanguage: 'Roman Urdu',
      );

      expect(result.single.script, CaptionScript.latin);
      expect(result.single.language, 'Roman Urdu');
    });

    test('adds direction marks around mixed segments', () {
      final segments = <CaptionSegment>[
        const CaptionSegment(text: 'hello', language: 'English', script: CaptionScript.latin),
        const CaptionSegment(text: 'بازار', language: 'Urdu', script: CaptionScript.arabic),
      ];

      final rendered = MixedTranscriptParser.withDirectionMarks(segments);
      expect(rendered, contains('\u200Ehello\u200E'));
      expect(rendered, contains('\u200Fبازار\u200F'));
    });
  });

  group('Caption segment persistence', () {
    test('round-trips segments through JSON', () {
      final caption = Caption(
        text: 'hello بازار',
        segments: const [
          CaptionSegment(text: 'hello', language: 'English', script: CaptionScript.latin),
          CaptionSegment(text: 'بازار', language: 'Urdu', script: CaptionScript.arabic),
        ],
      );

      final decoded = Caption.fromJson(caption.toJson());
      expect(decoded.segments.length, 2);
      expect(decoded.segments[0].language, 'English');
      expect(decoded.segments[1].language, 'Urdu');
      expect(decoded.segments[1].script, CaptionScript.arabic);
    });

    test('legacy captions without segments remain readable', () {
      final legacy = Caption.fromJson({
        'id': 'legacy',
        'text': 'hello بازار',
        'speaker': 'Speaker 1',
        'timestamp': DateTime.now().toIso8601String(),
        'language': 'English',
        'isPartial': false,
        'isOwn': false,
      });

      expect(legacy.text, 'hello بازار');
      expect(legacy.segments, isEmpty);
    });
  });
}
