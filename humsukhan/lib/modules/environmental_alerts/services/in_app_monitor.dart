import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/models.dart';
import '../../../services/audio/pcm_source.dart';
import '../models/monitoring_status.dart';
import 'environmental_alert_pipeline.dart';
import 'environmental_monitor.dart';
import 'sound_detection_engine.dart';

/// iOS: monitoring runs inside the app, which keeps recording in the
/// background through the `audio` background mode once started.
///
/// Every start builds the recorder and engine afresh, so stopping and
/// starting again can never inherit a half-released microphone.
class InAppMonitor extends EnvironmentalMonitor {
  InAppMonitor({
    PcmSource Function()? source,
    SoundDetectionEngine Function(void Function(SoundEvent) onDetected)? engine,
    EnvironmentalAlertPipeline? pipeline,
  })  : _newSource = source ?? RecorderPcmSource.new,
        _newEngine = engine ?? ((onDetected) => SoundDetectionEngine(onDetected: onDetected)),
        _pipeline = pipeline ?? EnvironmentalAlertPipeline();

  final PcmSource Function() _newSource;
  final SoundDetectionEngine Function(void Function(SoundEvent)) _newEngine;
  final EnvironmentalAlertPipeline _pipeline;
  final StreamController<MonitorUpdate> _updates = StreamController.broadcast();

  MonitoringStatus _status = MonitoringStatus.off;
  MonitoringFailure? _failure;
  PcmSource? _source;
  SoundDetectionEngine? _engine;
  StreamSubscription<Uint8List>? _audio;

  /// Bumped by every start and stop, so work from a superseded run that
  /// completes late cannot change the current one.
  int _run = 0;

  @override
  MonitoringStatus get status => _status;
  @override
  MonitoringFailure? get failure => _failure;
  @override
  Stream<MonitorUpdate> get updates => _updates.stream;

  @override
  Future<void> attach() async {}

  @override
  Future<void> start() async {
    if (!_status.canStart) return;
    final run = ++_run;
    _set(MonitoringStatus.starting);

    final source = _source = _newSource();
    if (!await source.hasPermission()) {
      return _fail(run, MonitoringFailure.microphoneUnavailable);
    }
    if (run != _run) return;

    final engine = _engine = _newEngine((event) => _onDetected(run, event));
    if (!await engine.start()) return _fail(run, MonitoringFailure.model);
    if (run != _run) return;

    try {
      final stream = await source.start();
      if (run != _run) return;
      _audio = stream.listen(
        engine.addPcm,
        onError: (Object e) {
          debugPrint('Environmental audio stream error: $e');
          _fail(run, MonitoringFailure.capture);
        },
        onDone: () {
          if (run == _run && _status == MonitoringStatus.active) _fail(run, MonitoringFailure.capture);
        },
      );
    } catch (e) {
      debugPrint('Environmental recorder could not start: $e');
      return _fail(run, MonitoringFailure.capture);
    }
    _set(MonitoringStatus.active);
  }

  @override
  Future<void> stop() async {
    if (_status.canStart) return;
    _run++;
    _set(MonitoringStatus.stopping);
    await _release();
    _set(MonitoringStatus.off);
  }

  Future<void> _onDetected(int run, SoundEvent event) async {
    if (run != _run) return;
    final announced = await _pipeline.handle(event);
    if (announced != null && run == _run) {
      _updates.add(MonitorUpdate(_status, alert: announced));
    }
  }

  Future<void> _fail(int run, MonitoringFailure failure) async {
    if (run != _run) return;
    _run++;
    await _release();
    _set(MonitoringStatus.error, failure);
  }

  Future<void> _release() async {
    await _audio?.cancel();
    _audio = null;
    _engine?.stop();
    _engine = null;
    final source = _source;
    _source = null;
    try {
      await source?.stop();
    } catch (e) {
      debugPrint('Environmental recorder release failed: $e');
    }
  }

  void _set(MonitoringStatus status, [MonitoringFailure? failure]) {
    _status = status;
    _failure = failure;
    _updates.add(MonitorUpdate(status, failure: failure));
  }
}
