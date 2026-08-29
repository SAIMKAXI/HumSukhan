import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/sound_detection_service.dart';
import 'settings_provider.dart';

class EnvironmentalProvider extends ChangeNotifier {
  bool _monitoringEnabled = false;
  final List<SoundEvent> _alertHistory = [];
  SoundEvent? _currentAlert;
  final bool _isProcessing = false;
  String? _lastAlertType;
  DateTime? _lastAlertTime;

  static const _cooldownDuration = Duration(seconds: 30);
  static const _minConfidence = 0.6;
  SettingsProvider? _settingsProvider;
  final SoundDetectionService _soundService = SoundDetectionService.instance;

  /// Set the settings provider for alert feedback integration.
  void setSettingsProvider(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  // Getters
  bool get monitoringEnabled => _monitoringEnabled;
  List<SoundEvent> get alertHistory => List.unmodifiable(_alertHistory);
  SoundEvent? get currentAlert => _currentAlert;
  bool get isProcessing => _isProcessing;

  List<SoundEvent> get recentAlerts {
    final sorted = List<SoundEvent>.from(_alertHistory);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(20).toList();
  }

  static const Map<String, String> alertDescriptions = {
    'Fire Alarm': 'A possible fire alarm was detected. Please check your surroundings.',
    'Smoke Alarm': 'A possible smoke alarm was detected. Please verify safety.',
    'Siren': 'A siren sound was detected nearby.',
    'Doorbell': 'A doorbell sound was detected.',
    'Knock': 'A knocking sound was detected at a door.',
    'Phone': 'A phone ringtone was detected.',
    'Alarm Clock': 'An alarm clock sound was detected.',
    'Baby Cry': 'A baby crying sound was detected.',
  };

  void toggleMonitoring() async {
    _monitoringEnabled = !_monitoringEnabled;

    if (_monitoringEnabled) {
      // Initialize and start the real sound detection service
      await _soundService.initialize();
      _soundService.onSoundDetected = (event) {
        processSoundEvent(event);
      };
      await _soundService.startMonitoring();
    } else {
      _soundService.stopMonitoring();
      _currentAlert = null;
    }
    notifyListeners();
  }

  // Sound event processing with validation pipeline
  bool processSoundEvent(SoundEvent event) {
    // Confidence check
    if (event.confidence < _minConfidence) return false;

    // Cooldown check
    if (_lastAlertType == event.type && _lastAlertTime != null) {
      if (DateTime.now().difference(_lastAlertTime!) < _cooldownDuration) {
        return false;
      }
    }

    // Add to history
    _alertHistory.add(event);
    _currentAlert = event;
    _lastAlertType = event.type;
    _lastAlertTime = DateTime.now();
    notifyListeners();

    // Trigger alert feedback (haptic, screen flash, flashlight)
    if (_settingsProvider != null) {
      AlertService.instance.triggerAlert(_settingsProvider!, severity: event.severity);
    }

    return true;
  }

  void dismissAlert() {
    if (_currentAlert != null) {
      final idx = _alertHistory.indexWhere((a) => a.id == _currentAlert!.id);
      if (idx != -1) {
        _alertHistory[idx] = _alertHistory[idx].copyWith(dismissed: true);
      }
    }
    _currentAlert = null;
    notifyListeners();
  }

  void clearHistory() {
    _alertHistory.clear();
    notifyListeners();
  }

  /// Manually trigger a test alert.
  /// This uses the real SoundEvent model but is triggered manually.
  void simulateAlert(String type, {double confidence = 0.85}) {
    final event = SoundEvent(
      type: type,
      confidence: confidence,
      severity: (type == 'Fire Alarm' || type == 'Smoke Alarm') ? 'critical' : 'warning',
    );
    processSoundEvent(event);
  }

  @override
  void dispose() {
    _soundService.dispose();
    super.dispose();
  }
}
