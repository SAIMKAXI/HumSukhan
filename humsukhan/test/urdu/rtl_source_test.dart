import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layout is written in terms of start and end, so it mirrors for Urdu.
/// Left and right appear only where the side is meant literally: alignment
/// chosen from the script of a piece of text, or a decorative gradient.
void main() {
  test('screens use start and end rather than left and right', () {
    final sideBound = RegExp(
      r'EdgeInsets\.only\([^)]*\b(left|right):|EdgeInsets\.fromLTRB\(\s*([\d.]+)\s*,\s*[\d.]+\s*,\s*([\d.]+)|'
      r'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)|TextAlign\.(left|right)|'
      r'Positioned\([^)]*\b(left|right):',
    );
    final deliberate = RegExp(r'urdu\s*\?|Urdu\s*\?|begin:|end:');
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final match in sideBound.allMatches(line)) {
          // fromLTRB with the same value on both sides is symmetric.
          if (match[2] != null && match[2] == match[3]) continue;
          if (deliberate.hasMatch(line)) continue;
          found.add('${file.path}:${i + 1}: ${match[0]}');
        }
      }
    }
    expect(found, isEmpty, reason: 'Use EdgeInsetsDirectional, AlignmentDirectional or TextAlign.start/end:\n${found.join('\n')}');
  });
}
