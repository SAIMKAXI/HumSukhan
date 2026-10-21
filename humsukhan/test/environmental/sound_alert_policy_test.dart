import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/models/environmental_sound.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_alert_policy.dart';

SoundTag tag(String label, double probability) => (label: label, probability: probability);

void main() {
  late DateTime now;
  late SoundAlertPolicy policy;

  setUp(() {
    now = DateTime(2026, 10, 21, 12);
    policy = SoundAlertPolicy(clock: () => now);
  });

  test('the catalog is exactly the sounds that can be detected', () {
    expect(EnvironmentalSound.types, ['Siren', 'Doorbell', 'Knock']);
    for (final retired in ['Baby Cry', 'Smoke Alarm', 'Phone', 'Vehicle Horn', 'Glass Break', 'Alarm Clock', 'Dog Bark']) {
      expect(EnvironmentalSound.byType(retired), isNull, reason: retired);
    }
  });

  test('every model label that means a supported sound is recognised', () {
    final expected = {
      'Siren': 'Siren',
      'Civil defense siren': 'Siren',
      'Police car (siren)': 'Siren',
      'Ambulance (siren)': 'Siren',
      'Fire engine, fire truck (siren)': 'Siren',
      'Emergency vehicle': 'Siren',
      'Doorbell': 'Doorbell',
      'Ding-dong': 'Doorbell',
      'Knock': 'Knock',
      'Tap': 'Knock',
    };
    expected.forEach((label, type) {
      expect(EnvironmentalSound.forLabel(label)?.type, type, reason: label);
    });
  });

  test('labels that merely contain a supported word do not raise an alert', () {
    // Each of these matched the old substring mapping.
    final events = policy.evaluate([
      tag('Water tap, faucet', 0.99),
      tag('Tapping (guitar technique)', 0.99),
      tag('Engine knocking', 0.99),
      tag('Wind chime', 0.99),
      tag('Chime', 0.99),
    ]);
    expect(events, isEmpty);
  });

  test('a sound must reach its own threshold', () {
    expect(policy.evaluate([tag('Siren', 0.69)]), isEmpty);
    expect(policy.evaluate([tag('Doorbell', 0.54)]), isEmpty);

    final siren = policy.evaluate([tag('Siren', 0.70)]).single;
    expect(siren.type, 'Siren');
    expect(siren.severity, 'critical');

    final doorbell = policy.evaluate([tag('Doorbell', 0.55)]).single;
    expect(doorbell.type, 'Doorbell');
    expect(doorbell.severity, 'warning');
  });

  test('a sound scored under several labels is one alert at its best confidence', () {
    final events = policy.evaluate([tag('Siren', 0.4), tag('Ambulance (siren)', 0.86), tag('Emergency vehicle', 0.75)]);
    expect(events, hasLength(1));
    expect(events.single.confidence, 0.86);
  });

  test('two different sounds in one window are both reported, most severe first', () {
    final events = policy.evaluate([tag('Knock', 0.8), tag('Siren', 0.9)]);
    expect(events.map((e) => e.type), ['Siren', 'Knock']);
  });

  test('a sound is not repeated within the cooldown, and other sounds are unaffected', () {
    expect(policy.evaluate([tag('Doorbell', 0.9)]), hasLength(1));

    now = now.add(const Duration(seconds: 29));
    expect(policy.evaluate([tag('Doorbell', 0.9)]), isEmpty);
    expect(policy.evaluate([tag('Knock', 0.9)]), hasLength(1));

    now = now.add(const Duration(seconds: 1));
    expect(policy.evaluate([tag('Doorbell', 0.9)]), hasLength(1));
  });

  test('reset forgets the cooldown', () {
    policy.evaluate([tag('Siren', 0.9)]);
    policy.reset();
    expect(policy.evaluate([tag('Siren', 0.9)]), hasLength(1));
  });

  test('labels are matched regardless of case and surrounding space', () {
    expect(policy.evaluate([tag('  DOORBELL ', 0.9)]).single.type, 'Doorbell');
  });
}
