import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('professional insight round-trips bullet summaries without obsolete fields', () {
    final insight = ProfessionalInsight(
      sessionId: 'session',
      summary: 'Decision made. Next step assigned.',
      summaryBullets: const ['Decision made.', 'Next step assigned.'],
      actionItems: const ['Prepare report'],
      deadlines: const ['Tomorrow'],
    );
    final restored = ProfessionalInsight.fromJson(insight.toJson());
    expect(restored.summaryBullets, ['Decision made.', 'Next step assigned.']);
    expect(restored.actionItems, ['Prepare report']);
    expect(restored.deadlines, ['Tomorrow']);
  });
}
