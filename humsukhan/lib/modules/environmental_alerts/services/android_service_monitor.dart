import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../models/models.dart';
import '../models/monitoring_status.dart';
import 'environmental_monitor.dart';

/// Android: monitoring runs in `EnvironmentalMonitoringService`, a microphone
/// foreground service that keeps listening while the app is closed and that
/// the Quick Settings tile drives directly. The service owns the state; this
/// class only asks it to change and reports what it says.
class AndroidServiceMonitor extends EnvironmentalMonitor {
  AndroidServiceMonitor({
    MethodChannel channel = const MethodChannel(methodChannelName),
    EventChannel events = const EventChannel(eventChannelName),
    this.pollInterval = const Duration(milliseconds: 200),
    this.startTimeout = const Duration(seconds: 15),
    this.stopTimeout = const Duration(seconds: 5),
  })  : _channel = channel,
        _events = events;

  static const methodChannelName = 'com.humsukhan/environmental_monitor';
  static const eventChannelName = 'com.humsukhan/environmental_monitor/events';

  final MethodChannel _channel;
  final EventChannel _events;
  final Duration pollInterval;
  final Duration startTimeout;
  final Duration stopTimeout;
  final StreamController<MonitorUpdate> _updates = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  MonitoringStatus _status = MonitoringStatus.off;
  MonitoringFailure? _failure;

  @override
  MonitoringStatus get status => _status;
  @override
  MonitoringFailure? get failure => _failure;
  @override
  Stream<MonitorUpdate> get updates => _updates.stream;

  @override
  Future<void> attach() async {
    _subscription ??= _events.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (Object error) => debugPrint('Environmental monitor event error: $error'),
    );
    await _refresh();
  }

  @override
  Future<void> start() async {
    await attach();
    if (_status == MonitoringStatus.active) return;
    if (_status == MonitoringStatus.stopping) {
      _set(MonitoringStatus.error, MonitoringFailure.busy);
      return;
    }
    if (_status != MonitoringStatus.starting) {
      try {
        await _channel.invokeMethod<bool>('start');
      } on PlatformException catch (e) {
        _set(MonitoringStatus.error, MonitoringFailure.fromCode(e.code));
        return;
      }
      _set(MonitoringStatus.starting);
    }

    final settled = await _waitFor(
      (status) => status == MonitoringStatus.active || status == MonitoringStatus.error,
      startTimeout,
    );
    if (!settled) {
      // The service never confirmed audio. Do not leave it holding the
      // microphone while the screen says monitoring failed.
      await _requestStop();
      _set(MonitoringStatus.error, MonitoringFailure.service);
    }
  }

  @override
  Future<void> stop() async {
    await attach();
    if (_status.canStart) return;
    await _requestStop();
    if (!_status.canStart) _set(MonitoringStatus.error, MonitoringFailure.stopFailed);
  }

  Future<void> _requestStop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      debugPrint('Environmental monitor stop request failed: $e');
    }
    if (!_status.canStart) _set(MonitoringStatus.stopping);
    await _waitFor((status) => status.canStart, stopTimeout);
  }

  /// Polls as well as listening: the event channel only delivers while the
  /// activity is registered, and a missed broadcast must not leave the screen
  /// waiting forever.
  Future<bool> _waitFor(bool Function(MonitoringStatus) done, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      await _refresh();
      if (done(_status)) return true;
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _refresh() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getStatus');
      if (raw is Map) _apply(raw);
    } catch (e) {
      debugPrint('Environmental monitor status unavailable: $e');
    }
  }

  void _onNativeEvent(dynamic value) {
    if (value is Map) _apply(value);
  }

  void _apply(Map<dynamic, dynamic> payload) {
    final status = MonitoringStatus.fromWire(payload['state']?.toString());
    final failure = status == MonitoringStatus.error
        ? MonitoringFailure.fromCode(payload['error']?.toString())
        : null;
    final alert = _decodeAlert(payload['event']);
    if (status == _status && failure == _failure && alert == null) return;
    _status = status;
    _failure = failure;
    _updates.add(MonitorUpdate(status, failure: failure, alert: alert));
  }

  void _set(MonitoringStatus status, [MonitoringFailure? failure]) {
    _status = status;
    _failure = failure;
    _updates.add(MonitorUpdate(status, failure: failure));
  }

  static SoundEvent? _decodeAlert(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return SoundEvent.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('Environmental alert from the service could not be read: $e');
      return null;
    }
  }
}
