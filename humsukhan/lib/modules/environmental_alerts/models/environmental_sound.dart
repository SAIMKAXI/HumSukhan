/// The sounds Environmental Alerts can report, and everything the pipeline
/// needs to know about each one.
///
/// This is the single source of truth: the detector's label mapping, the
/// confidence each sound must reach, its severity and the description shown
/// on screen all live here, so they cannot drift apart.
class EnvironmentalSound {
  const EnvironmentalSound._({
    required this.type,
    required this.severity,
    required this.threshold,
    required this.labels,
    required this.description,
  });

  /// Name used in history, settings and notifications.
  final String type;

  /// `critical` or `warning`, as understood by `AppTheme.alertColor`.
  final String severity;

  /// Minimum classifier probability before the sound is reported.
  final double threshold;

  /// Exact AudioSet display names (lower case) produced by the CED model.
  ///
  /// Matched whole, never as substrings: "Water tap, faucet",
  /// "Engine knocking" and "Wind chime" must not become a knock or a
  /// doorbell.
  final Set<String> labels;

  final String description;

  static const siren = EnvironmentalSound._(
    type: 'Siren',
    severity: 'critical',
    threshold: 0.70,
    labels: {
      'siren',
      'civil defense siren',
      'police car (siren)',
      'ambulance (siren)',
      'fire engine, fire truck (siren)',
      'emergency vehicle',
    },
    description: 'A siren sound was detected nearby.',
  );

  static const doorbell = EnvironmentalSound._(
    type: 'Doorbell',
    severity: 'warning',
    threshold: 0.55,
    labels: {'doorbell', 'ding-dong'},
    description: 'A doorbell sound was detected.',
  );

  static const knock = EnvironmentalSound._(
    type: 'Knock',
    severity: 'warning',
    threshold: 0.55,
    // AudioSet files "Tap" beside "Knock" under Door: a light knock.
    labels: {'knock', 'tap'},
    description: 'A knocking sound was detected at a door.',
  );

  static const List<EnvironmentalSound> all = [siren, doorbell, knock];

  static List<String> get types => [for (final sound in all) sound.type];

  static EnvironmentalSound? byType(String type) {
    for (final sound in all) {
      if (sound.type == type) return sound;
    }
    return null;
  }

  static EnvironmentalSound? forLabel(String label) {
    final normalized = label.trim().toLowerCase();
    for (final sound in all) {
      if (sound.labels.contains(normalized)) return sound;
    }
    return null;
  }
}
