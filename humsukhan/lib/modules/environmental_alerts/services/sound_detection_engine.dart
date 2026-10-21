import 'dart:math' as math;
import 'dart:typed_data';

import '../../../models/models.dart';
import 'pcm_window_accumulator.dart';
import 'sound_alert_policy.dart';
import 'sound_classifier.dart';

/// PCM in, alerts out.
///
/// The engine does not own a microphone. On Android the foreground service
/// captures audio and hands it to the background isolate; on iOS the in-app
/// monitor records it. Both feed the same engine, so detection behaves the
/// same wherever the audio came from.
///
/// Pipeline: 16 kHz mono PCM16 → 3 s window every 1 s → loudness gate →
/// CED-Tiny tagging → [SoundAlertPolicy].
class SoundDetectionEngine {
  SoundDetectionEngine({
    required this.onDetected,
    SoundClassifier? classifier,
    SoundAlertPolicy? policy,
  })  : _classifier = classifier ?? SherpaSoundClassifier(),
        _policy = policy ?? SoundAlertPolicy();

  static const int sampleRate = 16000;

  /// RMS below which a window is treated as silence and not classified
  /// (200 on the 16-bit scale).
  static const double silenceRms = 200 / 32768;

  final void Function(SoundEvent event) onDetected;
  final SoundClassifier _classifier;
  final SoundAlertPolicy _policy;
  final PcmWindowAccumulator _windows = PcmWindowAccumulator(
    windowSamples: 3 * sampleRate,
    hopSamples: sampleRate,
  );
  bool _running = false;

  bool get isRunning => _running;

  /// Loads the model. Returns false, and stays stopped, if it cannot.
  Future<bool> start() async {
    if (_running) return true;
    if (!await _classifier.load()) return false;
    _windows.reset();
    _policy.reset();
    _running = true;
    return true;
  }

  void addPcm(Uint8List bytes) {
    if (!_running) return;
    _windows.add(bytes, _analyse);
  }

  void stop() {
    _running = false;
    _windows.reset();
    _policy.reset();
    _classifier.release();
  }

  void _analyse(Float32List window) {
    if (!_running || rms(window) < silenceRms) return;
    for (final event in _policy.evaluate(_classifier.classify(window))) {
      onDetected(event);
    }
  }

  static double rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }
}
