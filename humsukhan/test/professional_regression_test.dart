import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/conversation/services/mixed_transcript_parser.dart';

void main() {
  test('folder copyWith can explicitly clear a custom folder', () {
    final session = ProfessionalSession(
      title: 'Meeting',
      folderId: 'folder-1',
    );

    final moved = session.copyWith(folderId: null);

    expect(moved.folderId, isNull);
  });

  test('Roman Urdu stays Latin-script and is never converted to Devanagari', () {
    final segments = MixedTranscriptParser.parse(
      'main theek hoon aur aap kaise hain',
      fallbackLanguage: 'Roman Urdu',
    );

    expect(segments.length, 1);
    expect(segments.single.script, CaptionScript.romanUrdu);
    expect(segments.single.language, 'Roman Urdu');
    expect(segments.single.text, contains('main theek hoon'));
    expect(segments.any((s) => s.script == CaptionScript.devanagari), isFalse);
  });

  test('English preference still preserves Urdu script as Urdu content', () {
    final segments = MixedTranscriptParser.parse(
      'Please say بازار again',
      fallbackLanguage: 'English',
    );

    expect(segments.map((s) => s.script), [
      CaptionScript.latin,
      CaptionScript.arabic,
      CaptionScript.latin,
    ]);
    expect(segments[1].language, 'Urdu');
    expect(segments[1].text, 'بازار');
  });
}
