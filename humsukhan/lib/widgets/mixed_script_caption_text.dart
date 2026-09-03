import 'package:flutter/material.dart';

import '../services/everyday_language_policy.dart';

/// Renders mixed Urdu/English captions as structured directional runs.
///
/// Caption strings stay plain semantic text; bidi control characters are not
/// persisted in the transcript or database.
class MixedScriptCaptionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int? maxLines;

  const MixedScriptCaptionText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
    this.maxLines,
  });

  List<({String text, TextDirection direction})> _runs() {
    final normalized = EverydayLanguagePolicy.sanitizeHindi(text).trim();
    if (normalized.isEmpty) return const [];

    final tokens = normalized.split(RegExp(r'\s+'));
    final result = <({String text, TextDirection direction})>[];
    for (final token in tokens) {
      final direction = EverydayLanguagePolicy.containsUrduScript(token)
          ? TextDirection.rtl
          : TextDirection.ltr;
      if (result.isNotEmpty && result.last.direction == direction) {
        final last = result.removeLast();
        result.add((text: '${last.text} $token', direction: direction));
      } else {
        result.add((text: token, direction: direction));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final runs = _runs();
    if (runs.isEmpty) return const SizedBox.shrink();

    final children = <InlineSpan>[];
    for (var i = 0; i < runs.length; i++) {
      if (i > 0) children.add(const TextSpan(text: ' '));
      final run = runs[i];
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Directionality(
            textDirection: run.direction,
            child: Text(run.text, maxLines: maxLines, overflow: overflow, style: style),
          ),
        ),
      );
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(style: style, children: children),
    );
  }
}
