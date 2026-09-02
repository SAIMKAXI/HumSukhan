import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('professional insight exposes only retained intelligence fields', () {
    final insight = ProfessionalInsight(sessionId: 's', summaryBullets: ['One']);
    expect(insight.summaryBullets, ['One']);
    expect(insight.actionItems, isEmpty);
    expect(insight.deadlines, isEmpty);
    expect(insight.mentionedPeople, isEmpty);
  });
}
