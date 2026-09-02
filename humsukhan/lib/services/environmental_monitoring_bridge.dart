import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EnvironmentalMonitoringBridge {
  EnvironmentalMonitoringBridge._();
  static final instance = EnvironmentalMonitoringBridge._();

  static const _channel = MethodChannel('com.humsukhan/environmental_monitor');
  static const _events = EventChannel('com.humsukhan/environmental_monitor/events');
  StreamSubscription<dynamic>? _subscription;

  String _state = 'OFF';
  String get state => _state;
  bool get isActive => _state == 'ACTIVE';

  Future<void> initialize({required void Function(String state, Map<String, dynamic>? event) onChange}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _subscription?.cancel();

    // Android exposes native service events through an EventChannel. iOS uses
    // the in-app local detector because Control Center cannot own a microphone
    // session without a WidgetKit extension target.
    if (Platform.isAndroid) {
      _subscription = _events.receiveBroadcastStream().listen((dynamic value) {
        if (value is! Map) return;
        final state = value['state']?.toString();
        if (state != null) _state = state;
        Map<String, dynamic>? event;
        final rawEvent = value['event'];
        if (rawEvent is String && rawEvent.isNotEmpty) {
          try { event = Map<String, dynamic>.from(jsonDecode(rawEvent) as Map); } catch (_) {}
        } else if (rawEvent is Map) {
          event = Map<String, dynamic>.from(rawEvent);
        }
        onChange(_state, event);
      }, onError: (Object error) {
        debugPrint('Environmental bridge stream error: $error');
      });
    }

    try {
      final value = await _channel.invokeMethod<String>('getState');
      if (value != null) _state = value;
      onChange(_state, null);
    } catch (e) {
      debugPrint('Environmental bridge state error: $e');
    }
  }

  Future<bool> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start');
      if (result != true) return false;

      // The native command only means the foreground service was requested.
      // Treat monitoring as started only after the background audio pipeline
      // reports ACTIVE (or ERROR). This prevents a false-positive UI state.
      for (var attempt = 0; attempt < 40; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          final state = await _channel.invokeMethod<String>('getState');
          if (state != null) _state = state;
        } catch (_) {}
        if (_state == 'ACTIVE') return true;
        if (_state == 'ERROR' || _state == 'OFF') return false;
      }
      debugPrint('Environmental monitoring start timed out in STARTING state');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Environmental bridge start error: ${e.code} ${e.message}');
      return false;
    }
  }

  Future<bool> stop() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stop');
      if (result == true) {
        _state = 'STOPPING';
      }
      return result == true;
    } catch (e) {
      debugPrint('Environmental bridge stop error: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
