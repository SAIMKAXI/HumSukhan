import 'dart:async';
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
  String? _errorMessage;

  static const _minConfidence = 0.6;

  void setSettingsProvider(SettingsProvider settings) => _settingsProvider = settings;
  bool get monitoringEnabled => _monitoringState == 'ACTIVE' || _monitoringState == 'STARTING';
  String get monitoringState => _monitoringState;
  bool get isStarting => _monitoringState == 'STARTING';
  bool get isStopping => _monitoringState == 'STOPPING';
  bool get hasError => _monitoringState == 'ERROR';
  bool get isProcessing => _soundService.isMonitoring;
  bool get isMicrophoneReady => _soundService.isMicrophoneReady;
  bool get isModelReady => _soundService.isModelReady;
  String? get errorMessage => _errorMessage;
  bool get isLocal => true;
  String get environmentalStatus => monitoringEnabled ? 'Monitoring locally' : 'Off';
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
    await _bridge.initialize(onChange: (state, event) {
      if (!_soundService.isMonitoring) {
        _monitoringState = state;
        notifyListeners();
      }
      if (event != null) {
        final type = event['type']?.toString();
        final confidence = (event['confidence'] as num?)?.toDouble();
        final severity = event['severity']?.toString() ?? 'warning';
        if (type != null && confidence != null) processSoundEvent(SoundEvent(type: type, confidence: confidence, severity: severity));
      }
    });
  }

  Future<void> toggleMonitoring() async {
    if (monitoringEnabled) {
      _monitoringState = 'STOPPING';
      _errorMessage = null;
      notifyListeners();
      _soundService.stopMonitoring();
      if (_bridge.isActive) await _bridge.stop();
      _monitoringState = 'OFF';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _monitoringState = 'ERROR';
      _errorMessage = 'Microphone permission was denied.';
      notifyListeners();
      return;
    }

    _monitoringState = 'STARTING';
    notifyListeners();
    final initialized = await _soundService.initialize(requestPermission: false);
    if (!initialized || !_soundService.isMicrophoneReady) {
      _monitoringState = 'ERROR';
      _errorMessage = 'Microphone is not available to the recorder.';
      notifyListeners();
      return;
    }

    _soundService.onSoundDetected = processSoundEvent;
    final started = await _soundService.startMonitoring(permissionAlreadyGranted: true);
    if (started) {
      _monitoringState = 'ACTIVE';
    } else if (!_soundService.isModelReady) {
      _monitoringState = 'ERROR';
      _errorMessage = 'The environmental sound model is unavailable. Download/restore the monitoring model and try again.';
    } else {
      _monitoringState = 'ERROR';
      _errorMessage = 'The microphone recorder could not start.';
    }
    notifyListeners();
  }

  bool processSoundEvent(SoundEvent event) {
    if (!monitoringEnabled || event.confidence < _minConfidence) return false;
    final settings = _settingsProvider;
    if (settings != null && settings.allowedAlerts[event.type] == false) return false;
    if (_lastAlertType == event.type && _lastAlertTime != null && DateTime.now().difference(_lastAlertTime!) < SoundDetectionService.cooldownDuration) return false;
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
    _soundService.stopMonitoring();
    unawaited(_bridge.dispose());
    super.dispose();
  }
}
