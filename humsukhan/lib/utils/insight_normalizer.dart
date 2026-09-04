class InsightNormalizer {
  static List<String> list(
    dynamic value, {
    int? maxItems,
  }) {
    if (value is! Iterable) return const [];

    final result = <String>[];
    for (final item in value) {
      final text = clean(item?.toString() ?? '');
      if (text.isEmpty) continue;
      if (_isNearDuplicate(result, text)) continue;
      result.add(text);
      if (maxItems != null && result.length >= maxItems) break;
    }
    return List.unmodifiable(result);
  }

  static String clean(String value) {
    return value
        .replaceAll(RegExp(r'[\u2018\u2019\u201C\u201D]'), "'")
        .replaceAll(RegExp(r'[\u2013\u2014]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^[•\-*]+\s*'), '')
        .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
        .trim();
  }

  static List<String> dedupeSummary(List<String> items) => list(items, maxItems: 6);
  static List<String> dedupeActions(List<String> items) => list(items, maxItems: 8);
  static List<String> dedupeDeadlines(List<String> items) => list(items, maxItems: 8);
  static List<String> dedupePeople(List<String> items) => list(items, maxItems: 12);

  static bool _isNearDuplicate(List<String> existing, String candidate) {
    final candidateKey = _canonical(candidate);
    final candidateTokens = _tokens(candidateKey);

    for (final item in existing) {
      final itemKey = _canonical(item);
      if (itemKey == candidateKey) return true;

      if (candidateKey.contains(itemKey) || itemKey.contains(candidateKey)) {
        final shorter = candidateKey.length < itemKey.length
            ? candidateKey.length
            : itemKey.length;
        final longer = candidateKey.length > itemKey.length
            ? candidateKey.length
            : itemKey.length;
        if (shorter >= 12 && shorter / longer >= .72) return true;
      }

      final itemTokens = _tokens(itemKey);
      if (candidateTokens.length < 3 || itemTokens.length < 3) continue;
      final intersection = candidateTokens.intersection(itemTokens).length;
      final union = candidateTokens.union(itemTokens).length;
      if (union > 0 && intersection / union >= .78) return true;
    }

    return false;
  }

  static String _canonical(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u061F?!.,;:()\[\]{}"“”‘’`]+'), ' ')
        .replaceAll(RegExp(r'[-_/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _tokens(String value) {
    return value
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toSet();
  }
}
