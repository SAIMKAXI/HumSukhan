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
      }, onError: (Object error) { debugPrint('Environmental bridge stream error: $error'); });
    }
    try {
      final value = await _channel.invokeMethod<String>('getState');
      if (value != null) _state = value;
      onChange(_state, null);
    } catch (e) { debugPrint('Environmental bridge state error: $e'); }
  }

  Future<bool> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start');
      if (result != true) return false;
      for (var attempt = 0; attempt < 60; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          final nextState = await _channel.invokeMethod<String>('getState');
          if (nextState != null) _state = nextState;
        } catch (_) {}
        if (_state == 'ACTIVE') return true;
        if (_state == 'ERROR' || _state == 'OFF') return false;
      }
      // Never let an unresolved native transition race an in-app fallback.
      // The caller must observe OFF before it can start another microphone.
      await _requestStopAndWaitForOff();
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
      if (result != true) return false;
      _state = 'STOPPING';
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          final nextState = await _channel.invokeMethod<String>('getState');
          if (nextState != null) _state = nextState;
        } catch (_) {}
        if (_state == 'OFF' || _state == 'ERROR') return _state == 'OFF';
      }
      return false;
    } catch (e) {
      debugPrint('Environmental bridge stop error: $e');
      return false;
    }
  }

  Future<bool> _requestStopAndWaitForOff() async {
    try { await _channel.invokeMethod<bool>('stop'); } catch (_) {}
    _state = 'STOPPING';
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        final nextState = await _channel.invokeMethod<String>('getState');
        if (nextState != null) _state = nextState;
      } catch (_) {}
      if (_state == 'OFF' || _state == 'ERROR') return _state == 'OFF';
    }
    return false;
  }

  Future<void> dispose() async { await _subscription?.cancel(); _subscription = null; }
}
