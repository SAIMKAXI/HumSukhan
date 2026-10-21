import '../../../models/models.dart';
import '../models/environmental_sound.dart';

/// One label the classifier assigned to a window, with its probability.
typedef SoundTag = ({String label, double probability});

/// Decides which classifier output becomes an alert.
///
/// Every rule that turns a tag into an alert lives here and nowhere else:
/// exact label matching, the per-sound threshold, and a per-sound cooldown so
/// one doorbell ring does not become a run of alerts.
class SoundAlertPolicy {
  SoundAlertPolicy({this.cooldown = defaultCooldown, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const Duration defaultCooldown = Duration(seconds: 30);

  final Duration cooldown;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastAlertAt = {};

  /// Returns the alerts this window produces, most severe first.
  List<SoundEvent> evaluate(Iterable<SoundTag> tags) {
    // A siren usually scores under several labels at once ("Siren",
    // "Ambulance (siren)"); the sound's confidence is its best label.
    final best = <EnvironmentalSound, double>{};
    for (final tag in tags) {
      final sound = EnvironmentalSound.forLabel(tag.label);
      if (sound == null) continue;
      if (tag.probability > (best[sound] ?? 0)) best[sound] = tag.probability;
    }

    final now = _clock();
    final events = <SoundEvent>[];
    for (final sound in EnvironmentalSound.all) {
      final confidence = best[sound];
      if (confidence == null || confidence < sound.threshold) continue;
      final last = _lastAlertAt[sound.type];
      if (last != null && now.difference(last) < cooldown) continue;
      _lastAlertAt[sound.type] = now;
      events.add(SoundEvent(
        type: sound.type,
        confidence: confidence,
        severity: sound.severity,
        timestamp: now,
      ));
    }
    return events;
  }

  void reset() => _lastAlertAt.clear();
}
