import 'dart:async';
import 'dart:typed_data';

import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/in_app_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_alert_policy.dart';
import 'package:humsukhan/modules/environmental_alerts/services/sound_classifier.dart';

/// PCM16 little-endian bytes for [samples].
Uint8List pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// [seconds] of 16 kHz audio at a constant [level].
Uint8List tone(double seconds, int level) => pcm(List.filled((seconds * 16000).round(), level));

class FakeClassifier implements SoundClassifier {
  FakeClassifier({this.loads = true, List<SoundTag>? tags}) : tags = tags ?? [];

  bool loads;
  List<SoundTag> tags;
  int loadCalls = 0;
  int classifyCalls = 0;
  int releaseCalls = 0;

  @override
  Future<bool> load() async {
    loadCalls++;
    return loads;
  }

  @override
  List<SoundTag> classify(Float32List samples) {
    classifyCalls++;
    return tags;
  }

  @override
  void release() => releaseCalls++;
}

class FakePcmSource implements PcmSource {
  FakePcmSource({this.permitted = true, this.startError});

  bool permitted;
  Object? startError;
  final StreamController<Uint8List> audio = StreamController<Uint8List>();
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<Stream<Uint8List>> start() async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
    return audio.stream;
  }

  @override
  Future<void> stop() async => stopCalls++;
}

/// A monitor the test drives by hand.
class FakeMonitor extends EnvironmentalMonitor {
  final StreamController<MonitorUpdate> _updates = StreamController.broadcast(sync: true);
  MonitoringStatus _status = MonitoringStatus.off;
  MonitoringFailure? _failure;
  int startCalls = 0;
  int stopCalls = 0;

  /// What [start] ends in.
  MonitoringStatus startResult = MonitoringStatus.active;
  MonitoringFailure? startFailure;

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
    startCalls++;
    emit(MonitoringStatus.starting);
    emit(startResult, failure: startFailure);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    emit(MonitoringStatus.off);
  }

  void emit(MonitoringStatus status, {MonitoringFailure? failure, SoundEvent? alert}) {
    _status = status;
    _failure = failure;
    _updates.add(MonitorUpdate(status, failure: failure, alert: alert));
  }
}
