import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/utils/action_item_normalizer.dart';
import 'package:humsukhan/utils/insight_normalizer.dart';

void main() {
  group('Professional insight compatibility', () {
    final generatedAt = DateTime.utc(2026, 9, 4);

    test('legacy summary is preserved without becoming a structured bullet', () {
      final insight = ProfessionalInsight.fromJson({
        'id': 'legacy-1',
        'sessionId': 'session-1',
        'summary': 'The team agreed on the launch plan.',
        'generatedAt': generatedAt.toIso8601String(),
        'isAvailable': true,
      });

      expect(insight.summary, 'The team agreed on the launch plan.');
      expect(insight.summaryBullets, isEmpty);
      expect(insight.toJson()['summary'], 'The team agreed on the launch plan.');
      expect(insight.toJson()['summaryBullets'], isEmpty);
    });

    test('structured summary remains authoritative when legacy summary also exists', () {
      final insight = ProfessionalInsight.fromJson({
        'id': 'modern-1',
        'sessionId': 'session-1',
        'summary': 'Legacy summary should not replace structured data.',
        'summaryBullets': ['Decision: launch Friday.', 'Owner: Aisha.'],
        'generatedAt': generatedAt.toIso8601String(),
        'isAvailable': true,
      });

      expect(insight.summary, 'Legacy summary should not replace structured data.');
      expect(insight.summaryBullets, ['Decision: launch Friday.', 'Owner: Aisha.']);
    });

    test('malformed summaryBullets does not consume legacy summary', () {
      final insight = ProfessionalInsight.fromJson({
        'id': 'malformed-1',
        'sessionId': 'session-1',
        'summary': 'Keep this legacy text available for export.',
        'summaryBullets': {'unexpected': 'object'},
        'generatedAt': generatedAt.toIso8601String(),
        'isAvailable': true,
      });

      expect(insight.summary, 'Keep this legacy text available for export.');
      expect(insight.summaryBullets, isEmpty);
    });
  });

  group('Professional normalization contracts', () {
    test('summary normalization is bounded, deduplicated, and whitespace safe', () {
      final result = InsightNormalizer.dedupeSummary([
        'Decision: launch Friday.',
        '  Decision: launch Friday.  ',
        '- Owner: Aisha',
        'Owner: Aisha',
        '',
      ]);

      expect(result, ['Decision: launch Friday.', 'Owner: Aisha']);
    });

    test('actions exclude passive discussion and metadata statements', () {
      final result = ActionItemNormalizer.normalize([
        'Prepare the launch checklist.',
        'The team discussed the launch timeline.',
        'The deadline is Friday.',
        'Aisha will send the final build.',
      ]);

      expect(result, [
        'Prepare the launch checklist.',
        'Aisha will send the final build.',
      ]);
    });

    test('exact action-summary overlap is removed while richer context remains', () {
      final actions = ActionItemNormalizer.normalize([
        'Send the final build.',
        'Aisha will send the final build.',
      ]);
      final summary = ActionItemNormalizer.removeActionOverlap(
        summaryBullets: const [
          'Send the final build.',
          'The release candidate is ready.',
        ],
        actionItems: actions,
      );

      expect(actions, ['Send the final build.', 'Aisha will send the final build.']);
      expect(summary, ['The release candidate is ready.']);
    });
  });
}
