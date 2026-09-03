import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('professional insight model exposes only retained intelligence fields', () {
    final insight = ProfessionalInsight(
      sessionId: 'session-1',
      summaryBullets: const ['Decision: launch Friday.', 'Action: send the final build.'],
      actionItems: const ['Send the final build.'],
      deadlines: const ['Friday'],
      mentionedPeople: const ['Ali'],
      isAvailable: true,
    );

    final json = insight.toJson();
    expect(json.containsKey('summaryBullets'), isTrue);
    expect(json.containsKey('vocabulary'), isFalse);
    expect(json.containsKey('themes'), isFalse);
    expect(insight.summaryBullets.length, 2);
  });
}
