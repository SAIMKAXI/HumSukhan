import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('legacy paragraph summary remains readable as one bullet', () {
    final insight = ProfessionalInsight.fromJson({
      'id': 'i', 'sessionId': 's', 'summary': 'Legacy summary',
      'actionItems': [], 'deadlines': [], 'mentionedPeople': [],
      'generatedAt': DateTime.now().toIso8601String(), 'isAvailable': true,
    });
    expect(insight.summaryBullets, ['Legacy summary']);
  });
}
