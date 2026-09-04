import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/utils/insight_normalizer.dart';

void main() {
  test('normalizes whitespace and bullet prefixes', () {
    expect(
      InsightNormalizer.clean('  •  Decision:\n launch Friday.  '),
      'Decision: launch Friday.',
    );
  });

  test('removes exact duplicates case-insensitively', () {
    final result = InsightNormalizer.dedupeSummary([
      'Launch the beta Friday.',
      'launch the beta Friday.',
      'A separate decision was made.',
    ]);

    expect(result, ['Launch the beta Friday.', 'A separate decision was made.']);
  });

  test('removes punctuation and whitespace variants as near duplicates', () {
    final result = InsightNormalizer.dedupeActions([
      'Send the final build to QA.',
      'Send   the final build to QA',
      'Review the retention policy.',
    ]);

    expect(result, [
      'Send the final build to QA.',
      'Review the retention policy.',
    ]);
  });

  test('keeps materially different items', () {
    final result = InsightNormalizer.dedupePeople([
      'Ali Khan',
      'Sara Khan',
      'QA team',
    ]);

    expect(result.length, 3);
  });

  test('enforces collection bounds', () {
    final result = InsightNormalizer.dedupeSummary(
      List.generate(10, (index) => 'Decision $index is distinct.'),
    );

    expect(result.length, 6);
  });
}
