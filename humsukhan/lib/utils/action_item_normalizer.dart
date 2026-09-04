import 'insight_normalizer.dart';

/// Enforces the product contract for professional action items.
///
/// The AI service is responsible for extracting actions; this layer is the
/// deterministic safety net that removes obvious discussion/metadata lines,
/// preserves assignment and deadline wording, and keeps actions separate from
/// the contextual summary.
class ActionItemNormalizer {
  static const _taskVerbs = <String>{
    'add',
    'approve',
    'book',
    'call',
    'check',
    'complete',
    'confirm',
    'contact',
    'create',
    'deliver',
    'discuss',
    'draft',
    'email',
    'finish',
    'follow',
    'fix',
    'implement',
    'prepare',
    'review',
    'schedule',
    'send',
    'share',
    'submit',
    'test',
    'update',
    'upload',
    'write',
  };

  static const _commitmentMarkers = <String>{
    'will',
    'should',
    'must',
    'need to',
    'needs to',
    'have to',
    'has to',
    'responsible for',
    'follow up',
  };

  static const _discussionStarters = <String>{
    'discussed',
    'talked about',
    'mentioned',
    'noted',
    'reviewed',
    'considered',
    'explored',
    'covered',
    'talked through',
    'agreed',
    'decided',
    'the deadline is',
    'deadline:',
    'context:',
    'background:',
  };

  static List<String> normalize(List<String> items) {
    final candidates = <String>[];
    for (final raw in items) {
      final text = InsightNormalizer.clean(raw);
      if (text.isEmpty || !_isActionable(text)) continue;
      candidates.add(text);
    }
    return InsightNormalizer.dedupeActions(candidates);
  }

  /// Removes summary bullets that are effectively the same task already shown
  /// in Actions. Richer contextual bullets remain in Summary.
  static List<String> removeActionOverlap({
    required List<String> summaryBullets,
    required List<String> actionItems,
  }) {
    if (summaryBullets.isEmpty || actionItems.isEmpty) return summaryBullets;

    return summaryBullets.where((summary) {
      final summaryKey = _canonical(summary);
      if (summaryKey.isEmpty) return false;

      for (final action in actionItems) {
        final actionKey = _canonical(action);
        if (summaryKey == actionKey) return false;

        final summaryTokens = _tokens(summaryKey);
        final actionTokens = _tokens(actionKey);
        if (summaryTokens.length < 3 || actionTokens.length < 3) continue;

        final intersection = summaryTokens.intersection(actionTokens).length;
        final union = summaryTokens.union(actionTokens).length;
        if (union > 0 && intersection / union >= .85) return false;

        final shorter = summaryKey.length <= actionKey.length
            ? summaryKey
            : actionKey;
        final longer = summaryKey.length > actionKey.length
            ? summaryKey
            : actionKey;
        if (shorter.length >= 20 &&
            shorter.length / longer.length >= .82 &&
            _looksLikeAction(summary) == _looksLikeAction(action)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  static bool _isActionable(String value) {
    final key = _canonical(value);
    if (key.isEmpty) return false;

    if (_discussionStarters.any((marker) => key == marker || key.startsWith('$marker '))) {
      return false;
    }

    if (RegExp(r'^(there is|there are|the project|the team|the meeting|the deadline)\b')
        .hasMatch(key) &&
        !_containsTaskSignal(key)) {
      return false;
    }

    return _containsTaskSignal(key);
  }

  static bool _containsTaskSignal(String key) {
    if (_commitmentMarkers.any(key.contains)) return true;

    final words = key.split(' ');
    if (words.isNotEmpty && _taskVerbs.contains(words.first)) return true;

    for (var i = 0; i < words.length - 1; i++) {
      if ((words[i] == 'to' || words[i] == 'and') &&
          _taskVerbs.contains(words[i + 1])) {
        return true;
      }
    }

    return RegExp(r'\b(follow up with|send .* by|complete .* by|finish .* by|deliver .* by)\b')
        .hasMatch(key);
  }

  static bool _looksLikeAction(String value) => _containsTaskSignal(_canonical(value));

  static String _canonical(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length >= 2)
        .toSet();
  }
}
