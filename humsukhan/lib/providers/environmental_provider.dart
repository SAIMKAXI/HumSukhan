import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/environmental_monitoring_bridge.dart';
import '../services/sound_detection_service.dart';
import 'settings_provider.dart';

class EnvironmentalProvider extends ChangeNotifier {
  EnvironmentalProvider() { unawaited(_initializeNativeBridge()); }
  final EnvironmentalMonitoringBridge _bridge = EnvironmentalMonitoringBridge.instance;
  final SoundDetectionService _soundService = SoundDetectionService.instance;
  final List<SoundEvent> _alertHistory = [];
  SoundEvent? _currentAlert;
  String _monitoringState = 'OFF';
  String? _lastAlertType;
  DateTime? _lastAlertTime;
  SettingsProvider? _settingsProvider;
  bool _bridgeInitialized = false;

  static const _minConfidence = 0.6;

  void setSettingsProvider(SettingsProvider settings) => _settingsProvider = settings;
  bool get monitoringEnabled => _monitoringState == 'ACTIVE' || _monitoringState == 'STARTING';
  String get monitoringState => _monitoringState;
  bool get isStarting => _monitoringState == 'STARTING';
  bool get isStopping => _monitoringState == 'STOPPING';
  bool get hasError => _monitoringState == 'ERROR';
  bool get isProcessing => false;
  bool get isLocal => monitoringEnabled;
  String get environmentalStatus => monitoringEnabled ? 'Offline / Local' : 'Off';
  List<SoundEvent> get alertHistory => List.unmodifiable(_alertHistory);
  SoundEvent? get currentAlert => _currentAlert;

  List<SoundEvent> get recentAlerts {
    final sorted = List<SoundEvent>.from(_alertHistory)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(20).toList();
  }

  static const Map<String, String> alertDescriptions = {
    'Fire Alarm': 'A possible fire alarm was detected. Please check your surroundings.',
    'Siren': 'A siren sound was detected nearby.',
    'Doorbell': 'A doorbell sound was detected.',
    'Knock': 'A knocking sound was detected at a door.',
    'Phone': 'A phone ringtone was detected.',
    'Phone/Ringtone': 'A phone ringtone was detected.',
    'Alarm Clock': 'An alarm clock sound was detected.',
    'Baby Cry': 'A baby crying sound was detected.',
    'Vehicle Horn': 'A vehicle horn was detected.',
    'Glass Break': 'A possible glass break was detected.',
    'Dog Bark': 'A dog bark was detected.',
  };

  Future<void> _initializeNativeBridge() async {
    if (_bridgeInitialized) return;
    _bridgeInitialized = true;
    await _bridge.initialize(onChange: _handleNativeChange);
    _monitoringState = _bridge.state;
    notifyListeners();
  }

  void _handleNativeChange(String state, Map<String, dynamic>? event) {
    _monitoringState = state;
    if (event != null) {
      final type = event['type']?.toString();
      final confidence = (event['confidence'] as num?)?.toDouble();
      final severity = event['severity']?.toString() ?? 'warning';
      if (type != null && confidence != null) {
        processSoundEvent(SoundEvent(type: type, confidence: confidence, severity: severity));
      }
    }
    notifyListeners();
  }

  Future<void> toggleMonitoring() async {
    if (monitoringEnabled) {
      _monitoringState = 'STOPPING';
      notifyListeners();
      _soundService.stopMonitoring();
      await _bridge.stop();
      _monitoringState = 'OFF';
      notifyListeners();
      return;
    }
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _monitoringState = 'ERROR';
      notifyListeners();
      return;
    }
    _monitoringState = 'STARTING';
    notifyListeners();
    if (Platform.isIOS) {
      if (!await _bridge.start()) {
        _monitoringState = 'ERROR';
      } else {
        _soundService.onSoundDetected = processSoundEvent;
        _monitoringState = await _soundService.startMonitoring(permissionAlreadyGranted: true) ? 'ACTIVE' : 'ERROR';
      }
    } else {
      _monitoringState = await _bridge.start() ? 'ACTIVE' : 'ERROR';
    }
    notifyListeners();
  }

  bool processSoundEvent(SoundEvent event) {
    if (!monitoringEnabled || event.confidence < _minConfidence) return false;
    final settings = _settingsProvider;
    if (settings != null && settings.allowedAlerts[event.type] == false) return false;

    // Cooldown is owned here so native/background and Flutter paths behave identically.
    if (_lastAlertType == event.type && _lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < SoundDetectionService.cooldownDuration) {
      return false;
    }

    _alertHistory.add(event);
    _currentAlert = event;
    _lastAlertType = event.type;
    _lastAlertTime = DateTime.now();
    if (settings != null) AlertService.instance.triggerAlert(settings, severity: event.severity);
    notifyListeners();
    return true;
  }

  void dismissAlert() {
    if (_currentAlert != null) {
      final idx = _alertHistory.indexWhere((a) => a.id == _currentAlert!.id);
      if (idx != -1) _alertHistory[idx] = _alertHistory[idx].copyWith(dismissed: true);
    }
    _currentAlert = null;
    notifyListeners();
  }

  void clearHistory() { _alertHistory.clear(); notifyListeners(); }

  @override
  void dispose() {
    unawaited(_bridge.dispose());
    super.dispose();
  }
}
