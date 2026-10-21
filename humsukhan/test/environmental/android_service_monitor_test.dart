import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/modules/environmental_alerts/models/monitoring_status.dart';
import 'package:humsukhan/modules/environmental_alerts/services/android_service_monitor.dart';
import 'package:humsukhan/modules/environmental_alerts/services/environmental_monitor.dart';

/// Plays the native side: MainActivity's channel in front of the service.
class FakeNativeService {
  FakeNativeService(this.tester);

  final TestDefaultBinaryMessenger tester;
  String state = 'OFF';
  String? error;
  final List<String> calls = [];

  /// What the service does once asked to start.
  void Function() onStart = () {};
  void Function() onStop = () {};
  PlatformException? startRefusal;

  MockStreamHandlerEventSink? _sink;

  void install() {
    tester.setMockMethodCallHandler(const MethodChannel(AndroidServiceMonitor.methodChannelName), (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getStatus':
          return {'state': state, 'error': error};
        case 'start':
          if (startRefusal != null) throw startRefusal!;
          state = 'STARTING';
          onStart();
          return true;
        case 'stop':
          onStop();
          return true;
      }
      return null;
    });
    tester.setMockStreamHandler(
      const EventChannel(AndroidServiceMonitor.eventChannelName),
      MockStreamHandler.inline(onListen: (_, sink) => _sink = sink),
    );
  }

  void broadcast(Map<String, Object?> payload) => _sink?.success(payload);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeService native;
  late AndroidServiceMonitor monitor;
  late List<MonitorUpdate> updates;

  setUp(() {
    native = FakeNativeService(TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger)..install();
    monitor = AndroidServiceMonitor(
      pollInterval: const Duration(milliseconds: 1),
      startTimeout: const Duration(milliseconds: 200),
      stopTimeout: const Duration(milliseconds: 200),
    );
    updates = [];
    monitor.updates.listen(updates.add);
  });

  test('attach picks up monitoring already started from the Quick Settings tile', () async {
    native.state = 'ACTIVE';
    await monitor.attach();
    expect(monitor.status, MonitoringStatus.active);
  });

  test('start waits for the service to confirm audio before reporting ACTIVE', () async {
    var polls = 0;
    native.tester.setMockMethodCallHandler(const MethodChannel(AndroidServiceMonitor.methodChannelName), (call) async {
      if (call.method == 'start') {
        native.state = 'STARTING';
        return true;
      }
      if (call.method == 'getStatus') {
        // The service needs a few polls to load the model and open the mic.
        if (native.state == 'STARTING' && ++polls == 3) native.state = 'ACTIVE';
        return {'state': native.state};
      }
      return null;
    });

    await monitor.start();
    await pumpEventQueue();
    expect(monitor.status, MonitoringStatus.active);
    expect(updates.map((u) => u.status), containsAllInOrder([MonitoringStatus.starting, MonitoringStatus.active]));
  });

  test('a service failure arrives with its cause', () async {
    native.onStart = () {
      native.state = 'ERROR';
      native.error = 'MODEL';
    };
    await monitor.start();
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.model);
  });

  test('a refused start because the microphone is not granted names the permission', () async {
    native.startRefusal = PlatformException(code: 'MIC_PERMISSION');
    await monitor.start();
    expect(monitor.failure, MonitoringFailure.microphoneBlocked);
  });

  test('a service that never confirms audio is stopped rather than left holding the microphone', () async {
    native.onStop = () => native.state = 'OFF';
    await monitor.start();
    expect(native.calls, contains('stop'));
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.service);
  });

  test('stop waits for the service to report OFF', () async {
    native.state = 'ACTIVE';
    await monitor.attach();
    native.onStop = () => native.state = 'OFF';
    await monitor.stop();
    expect(monitor.status, MonitoringStatus.off);
  });

  test('a service that will not stop is reported, not shown as off', () async {
    native.state = 'ACTIVE';
    await monitor.attach();
    await monitor.stop();
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.stopFailed);
  });

  test('an alert broadcast by the service reaches the screen with its id', () async {
    native.state = 'ACTIVE';
    await monitor.attach();
    final event = SoundEvent(id: 'alert-1', type: 'Doorbell', severity: 'warning', confidence: 0.8);
    native.broadcast({'state': 'ACTIVE', 'event': jsonEncode(event.toJson())});
    await pumpEventQueue();

    expect(updates.last.alert?.id, 'alert-1');
    expect(updates.last.alert?.type, 'Doorbell');
  });

  test('status changes broadcast by the service are followed', () async {
    await monitor.attach();
    native.broadcast({'state': 'ERROR', 'error': 'CAPTURE'});
    await pumpEventQueue();
    expect(monitor.status, MonitoringStatus.error);
    expect(monitor.failure, MonitoringFailure.capture);
  });

  test('foreground speech gets the microphone back', () async {
    native.state = 'ACTIVE';
    await monitor.attach();
    native.onStop = () => native.state = 'OFF';
    expect(await monitor.releaseMicrophone(), isTrue);
    expect(monitor.status, MonitoringStatus.off);
  });

  test('foreground speech stops monitoring this side has not heard about yet', () async {
    // Started from the Quick Settings tile; no event reached the app.
    native.state = 'ACTIVE';
    native.onStop = () => native.state = 'OFF';
    expect(await monitor.releaseMicrophone(), isTrue);
    expect(native.calls, contains('stop'));
  });
}
