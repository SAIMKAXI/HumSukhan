import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/conversation/services/transcript_representation.dart';

void main() {
  group('TranscriptRepresentation', () {
    test('Auto converts common Urdu-as-Devanagari output to Urdu script', () {
      final result = TranscriptRepresentation.prepare(
        'आप कैसे हैं؟',
        selection: 'Auto',
        detectedLanguage: 'Auto',
      );

      expect(result.text, 'آپ کیسے ہیں؟');
      expect(result.segments.any((s) => s.script == CaptionScript.arabic), isTrue);
      expect(result.segments.any((s) => s.script == CaptionScript.devanagari), isFalse);
    });

    test('English preference keeps English and Romanizes Urdu segments', () {
      final result = TranscriptRepresentation.prepare(
        'I am fine آپ کیسے ہیں؟',
        selection: 'English',
        detectedLanguage: 'Auto',
      );

      expect(result.text, contains('I am fine'));
      expect(result.text, contains('aap kaise hain?'));
      expect(result.segments.any((s) => s.script == CaptionScript.romanUrdu), isTrue);
      expect(result.segments.where((s) => s.text.contains('I am fine')).length, 1);
    });

    test('Roman Urdu preference leaves Latin text intact', () {
      final result = TranscriptRepresentation.prepare(
        'main theek hoon',
        selection: 'Roman Urdu',
        detectedLanguage: 'Roman Urdu',
      );

      expect(result.text, 'main theek hoon');
      expect(result.segments.single.script, CaptionScript.romanUrdu);
    });

    test('mixed parser keeps Arabic segments RTL and Latin segments LTR', () {
      final result = TranscriptRepresentation.prepare(
        'I am going to بازار',
        selection: 'Auto',
        detectedLanguage: 'Auto',
      );

      expect(result.segments.map((s) => s.script), [
        CaptionScript.latin,
        CaptionScript.arabic,
      ]);
      expect(result.segments.last.isRtl, isTrue);
    });
  });
}
