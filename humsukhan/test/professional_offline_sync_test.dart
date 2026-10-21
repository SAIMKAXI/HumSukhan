import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('ProfessionalSession keeps transcript lines in captions only', () {
    final original = ProfessionalSession(
      id: '9bcd3f95-a6e2-4f35-80c5-b9e88aa1a8d1',
      title: 'Lecture',
      type: SessionType.lecture,
      createdAt: DateTime(2026, 10, 21, 9),
      expiresAt: DateTime(2026, 10, 28, 9),
      captions: [
        Caption(
          id: 'caption-a',
          text: 'Welcome everyone',
          timestamp: DateTime(2026, 10, 21, 9),
        ),
        Caption(
          id: 'caption-b',
          text: 'The exam is on Friday',
          timestamp: DateTime(2026, 10, 21, 9, 1),
        ),
      ],
    );

    final json = original.toJson();
    expect(json.containsKey('transcriptText'), isFalse);
    expect((json['captions'] as List), hasLength(2));

    // Older local records may contain the redundant field; the model should
    // safely ignore it while preserving caption content.
    final legacyJson = Map<String, dynamic>.from(json)
      ..['transcriptText'] = 'old duplicate transcript';
    final restored = ProfessionalSession.fromJson(legacyJson);

    expect(restored.captions.map((c) => c.text), [
      'Welcome everyone',
      'The exam is on Friday',
    ]);
  });
}
