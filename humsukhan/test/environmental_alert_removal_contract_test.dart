import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const retiredLabels = <String>[
    'Smoke Alarm',
    'Phone',
    'Vehicle Horn',
    'Glass Break',
    'Alarm Clock',
    'Dog Bark',
  ];

  test('retired alert labels are absent from production environmental code', () {
    final productionFiles = <String>[
      'lib/services/sound_detection_service.dart',
      'lib/providers/settings_provider.dart',
      'lib/providers/environmental_provider.dart',
      'lib/l10n/app_strings.dart',
    ];

    for (final path in productionFiles) {
      final source = File(path).readAsStringSync();
      for (final label in retiredLabels) {
        expect(source, isNot(contains(label)), reason: '$label remains in $path');
      }
    }
  });
}
