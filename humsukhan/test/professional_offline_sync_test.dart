import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/professional_provider.dart';

Caption caption(String id, String text, int minute) =>
    Caption(id: id, text: text, speaker: 'Speaker 1', timestamp: DateTime(2026, 10, 21, 9, minute));

ProfessionalSession session(List<Caption> captions, {String title = 'Lecture'}) => ProfessionalSession(
      id: 's1',
      title: title,
      createdAt: DateTime(2026, 10, 21, 9),
      captions: captions,
    );

void main() {
  test('captions recorded while offline survive a sync with the shorter cloud copy', () {
    // Started online (the cloud got the first caption), finished offline.
    final cloud = session([caption('a', 'Welcome everyone', 0)]);
    final local = session([
      caption('a', 'Welcome everyone', 0),
      caption('b', 'Today we cover pumps', 1),
      caption('c', 'Exam is on Friday', 2),
    ]);

    final merged = ProfessionalProvider.mergeSessions(local: local, cloud: cloud);

    expect(merged.captions.map((c) => c.id), ['a', 'b', 'c']);
    expect(merged.transcriptText, 'Speaker 1: Welcome everyone\nSpeaker 1: Today we cover pumps\nSpeaker 1: Exam is on Friday');
  });

  test('captions only the cloud has are kept too, in time order', () {
    final cloud = session([caption('a', 'one', 0), caption('c', 'three', 2)]);
    final local = session([caption('b', 'two', 1)]);

    final merged = ProfessionalProvider.mergeSessions(local: local, cloud: cloud);

    expect(merged.captions.map((c) => c.text), ['one', 'two', 'three']);
  });

  test('when the cloud already has everything, its copy is used unchanged', () {
    final cloud = session([caption('a', 'one', 0)], title: 'Renamed on another phone');
    final local = session([caption('a', 'one', 0)]);

    expect(identical(ProfessionalProvider.mergeSessions(local: local, cloud: cloud), cloud), isTrue);
  });
}
