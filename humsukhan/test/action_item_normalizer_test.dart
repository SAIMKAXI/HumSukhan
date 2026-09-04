import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/utils/action_item_normalizer.dart';

void main() {
  group('ActionItemNormalizer.normalize', () {
    test('keeps explicit tasks, owners, and attached deadlines', () {
      final result = ActionItemNormalizer.normalize([
        '• Send the final deck by Friday. ',
        'Aisha will review the numbers before the meeting.',
        'The team discussed the launch timeline.',
        'The deadline is Friday.',
        'We talked about budget options.',
      ]);

      expect(result, [
        'Send the final deck by Friday.',
        'Aisha will review the numbers before the meeting.',
      ]);
    });

    test('drops passive discussion and metadata statements', () {
      final result = ActionItemNormalizer.normalize([
        'The team agreed on the rollout approach.',
        'We discussed the customer feedback.',
        'The project background is clear.',
        'Deadline: next Tuesday.',
      ]);

      expect(result, isEmpty);
    });

    test('deduplicates equivalent action wording', () {
      final result = ActionItemNormalizer.normalize([
        'Review the budget proposal.',
        'Review the budget proposal!',
        'Please review the budget proposal.',
      ]);

      expect(result, hasLength(1));
      expect(result.single, 'Review the budget proposal.');
    });
  });

  test('removes task-only summary duplicates but keeps richer context', () {
    final result = ActionItemNormalizer.removeActionOverlap(
      summaryBullets: [
        'Send the final deck by Friday.',
        'The team approved the launch plan; Aisha will send the final deck by Friday.',
        'The launch plan was approved for Friday release.',
      ],
      actionItems: [
        'Send the final deck by Friday.',
      ],
    );

    expect(result, [
      'The team approved the launch plan; Aisha will send the final deck by Friday.',
      'The launch plan was approved for Friday release.',
    ]);
  });
}
