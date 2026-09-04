import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  final generatedAt = DateTime.parse('2026-09-04T00:00:00Z');

  Map<String, dynamic> base(Map<String, dynamic> values) => {
        'id': 'insight-1',
        'sessionId': 'session-1',
        'summary': 'Legacy summary text that must not become one bullet.',
        'summaryBullets': ['Canonical bullet one.', 'Canonical bullet two.'],
        'actionItems': ['Send the final build.'],
        'deadlines': ['Friday'],
        'mentionedPeople': ['Aisha'],
        'generatedAt': generatedAt.toIso8601String(),
        'isAvailable': true,
        ...values,
      };

  test('modern payload uses summaryBullets as the structured summary', () {
    final insight = ProfessionalInsight.fromJson(base({}));

    expect(insight.summary, 'Legacy summary text that must not become one bullet.');
    expect(insight.summaryBullets, ['Canonical bullet one.', 'Canonical bullet two.']);
  });

  test('legacy payload preserves summary but does not fabricate bullets', () {
    final insight = ProfessionalInsight.fromJson(base({
      'summaryBullets': null,
      'summary': 'A complete legacy summary with several sentences. It remains legacy data.',
    }));

    expect(insight.summary, 'A complete legacy summary with several sentences. It remains legacy data.');
    expect(insight.summaryBullets, isEmpty);
  });

  test('malformed summaryBullets are ignored without consuming legacy summary', () {
    final insight = ProfessionalInsight.fromJson(base({
      'summaryBullets': {'unexpected': 'object'},
    }));

    expect(insight.summaryBullets, isEmpty);
    expect(insight.summary, 'Legacy summary text that must not become one bullet.');
  });

  test('mixed payload prefers explicit structured bullets', () {
    final insight = ProfessionalInsight.fromJson(base({
      'summary': 'Older summary kept for compatibility.',
      'summaryBullets': ['New canonical bullet.'],
    }));

    expect(insight.summary, 'Older summary kept for compatibility.');
    expect(insight.summaryBullets, ['New canonical bullet.']);
    expect(insight.toJson()['summaryBullets'], ['New canonical bullet.']);
  });
}
