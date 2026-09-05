import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/audio_model_manager.dart';
import '../services/environmental_monitoring_bridge.dart';
import '../services/sound_detection_service.dart';
import 'settings_provider.dart';

class EnvironmentalProvider extends ChangeNotifier {
  EnvironmentalProvider() {
    unawaited(_initializeNativeBridge());
    unawaited(_loadAlertHistory());
  }

  static const _historyKey = 'environmentalAlertHistory';
  static const _maxHistoryEntries = 100;
  static const _minConfidence = 0.6;

  final EnvironmentalMonitoringBridge _bridge = EnvironmentalMonitoringBridge.instance;
  final SoundDetectionService _soundService = SoundDetectionService.instance;
  final AudioModelManager _modelManager = AudioModelManager.instance;
  final List<SoundEvent> _alertHistory = [];

  SoundEvent? _currentAlert;
  String _monitoringState = 'OFF';
  String? _lastAlertType;
  DateTime? _lastAlertTime;
  SettingsProvider? _settingsProvider;
  bool _bridgeInitialized = false;
  bool _usingInAppFallback = false;
  String? _errorMessage;
  Future<void> _historyWriteQueue = Future.value();

  void setSettingsProvider(SettingsProvider settings) => _settingsProvider = settings;

  bool get monitoringEnabled => _monitoringState == 'ACTIVE';
  String get monitoringState => _monitoringState;
  bool get isStarting => _monitoringState == 'STARTING';
  bool get isStopping => _monitoringState == 'STOPPING';
  bool get hasError => _monitoringState == 'ERROR';
  bool get isProcessing => Platform.isAndroid
      ? (_usingInAppFallback ? _soundService.isMonitoring : _bridge.isActive)
      : _soundService.isMonitoring;
  bool get isMicrophoneReady => Platform.isAndroid
      ? (_usingInAppFallback ? _soundService.isMicrophoneReady : _bridge.isActive)
      : _soundService.isMicrophoneReady;
  bool get isModelReady => Platform.isAndroid
      ? (_usingInAppFallback ? _soundService.isModelReady : _bridge.isActive && !hasError)
      : _soundService.isModelReady;
  String? get errorMessage => _errorMessage;
  bool get isLocal => true;
  String get environmentalStatus => monitoringEnabled ? 'Monitoring locally' : 'Off';
  List<SoundEvent> get alertHistory => List.unmodifiable(_alertHistory);
  SoundEvent? get currentAlert => _currentAlert;

  List<SoundEvent> get recentAlerts {
    final sorted = List<SoundEvent>.from(_alertHistory)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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

  Future<void> _loadAlertHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _alertHistory
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((item) => SoundEvent.fromJson(Map<String, dynamic>.from(item))),
            );
          _alertHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (_alertHistory.isNotEmpty) {
            _lastAlertType = _alertHistory.first.type;
            _lastAlertTime = _alertHistory.first.timestamp;
          }
        }
      }
    } catch (e) {
      debugPrint('Environmental alert history load error: $e');
    }
    notifyListeners();
  }

  Future<void> _saveAlertHistory() async {
    _historyWriteQueue = _historyWriteQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _historyKey,
          jsonEncode(
            _alertHistory.take(_maxHistoryEntries).map((event) => event.toJson()).toList(),
          ),
        );
      } catch (e) {
        debugPrint('Environmental alert history save error: $e');
      }
    });
    await _historyWriteQueue;
  }

  Future<void> _initializeNativeBridge() async {
    if (_bridgeInitialized) return;
    _bridgeInitialized = true;
    await _bridge.initialize(onChange: (state, event) {
      if (_usingInAppFallback && state != 'OFF') return;
      _monitoringState = state;
      if (event != null) {
        final type = event['type']?.toString();
        final confidence = (event['confidence'] as num?)?.toDouble();
        final severity = event['severity']?.toString() ?? 'warning';
        if (type != null && confidence != null) {
          processSoundEvent(
            SoundEvent(type: type, confidence: confidence, severity: severity),
          );
        }
      } else {
        notifyListeners();
      }
    });
  }

  /// Monitoring startup is local-only. The model download is an explicit
  /// setup operation and must never become a hidden network side effect of
  /// pressing Start Monitoring.
  Future<bool> _prepareModel() => _modelManager.initialize();

  Future<void> toggleMonitoring() async {
    if (isStarting || isStopping) return;

    if (_monitoringState == 'ACTIVE') {
      _monitoringState = 'STOPPING';
      _errorMessage = null;
      notifyListeners();

      if (Platform.isAndroid) {
        if (_usingInAppFallback) {
          _soundService.stopMonitoring();
          _usingInAppFallback = false;
          _monitoringState = 'OFF';
        } else {
          final stopped = await _bridge.stop();
          if (!stopped) {
            _monitoringState = 'ERROR';
            _errorMessage = 'Environmental monitoring could not be stopped safely. Try again.';
          }
        }
      } else {
        _soundService.stopMonitoring();
        _monitoringState = 'OFF';
      }
      notifyListeners();
      return;
    }

    _errorMessage = null;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _monitoringState = 'ERROR';
      _errorMessage = permission.isPermanentlyDenied
          ? 'Microphone permission is blocked. Open App Settings and allow Microphone, then tap Start Monitoring again.'
          : 'Microphone permission is required for Environmental Alerts.';
      notifyListeners();
      return;
    }

    if (Platform.isAndroid) {
      _monitoringState = 'STARTING';
      _usingInAppFallback = false;
      notifyListeners();
      final modelReady = await _prepareModel();
      if (!modelReady) {
        _monitoringState = 'ERROR';
        _errorMessage = 'The environmental sound model is not installed. Connect to the internet and complete model setup, then try again.';
        notifyListeners();
        return;
      }

      final started = await _bridge.start();
      if (started && _bridge.state == 'ACTIVE') {
        _usingInAppFallback = false;
        _monitoringState = 'ACTIVE';
        notifyListeners();
        return;
      }

      if (_bridge.state != 'OFF') {
        _monitoringState = 'ERROR';
        _errorMessage = 'Environmental monitoring could not start safely because the background service is still changing state. Try again in a moment.';
        notifyListeners();
        return;
      }

      final initialized = await _soundService.initialize(requestPermission: false);
      if (initialized && _soundService.isMicrophoneReady) {
        _soundService.onSoundDetected = processSoundEvent;
        final fallbackStarted = await _soundService.startMonitoring(permissionAlreadyGranted: true);
        if (fallbackStarted) {
          _usingInAppFallback = true;
          _monitoringState = 'ACTIVE';
          notifyListeners();
          return;
        }
      }

      _usingInAppFallback = false;
      _monitoringState = 'ERROR';
      _errorMessage = 'Environmental monitoring could not start. Check microphone permission and Android battery/background restrictions, then try again.';
      notifyListeners();
      return;
    }

    _monitoringState = 'STARTING';
    notifyListeners();
    final initialized = await _soundService.initialize(requestPermission: false);
    if (!initialized || !_soundService.isMicrophoneReady) {
      _monitoringState = 'ERROR';
      _errorMessage = 'Microphone access is unavailable. Allow microphone access in App Settings, then try again.';
      notifyListeners();
      return;
    }

    final modelReady = await _prepareModel();
    if (!modelReady) {
      _monitoringState = 'ERROR';
      _errorMessage = 'The environmental sound model is not installed. Connect to the internet and complete model setup, then try again.';
      notifyListeners();
      return;
    }

    _soundService.onSoundDetected = processSoundEvent;
    final started = await _soundService.startMonitoring(permissionAlreadyGranted: true);
    if (started) {
      _monitoringState = 'ACTIVE';
    } else if (!_soundService.isModelReady) {
      _monitoringState = 'ERROR';
      _errorMessage = 'The environmental sound model is unavailable. Try model setup, then start monitoring again.';
    } else {
      _monitoringState = 'ERROR';
      _errorMessage = 'The microphone recorder could not start. Check microphone access and try again.';
    }
    notifyListeners();
  }

  Future<void> openMicrophoneSettings() async {
    await openAppSettings();
  }

  bool processSoundEvent(SoundEvent event) {
    if (!monitoringEnabled || event.confidence < _minConfidence) return false;
    final settings = _settingsProvider;
    if (settings != null && settings.allowedAlerts[event.type] == false) return false;
    if (_lastAlertType == event.type &&
        _lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < SoundDetectionService.cooldownDuration) {
      return false;
    }

    _alertHistory.insert(0, event);
    if (_alertHistory.length > _maxHistoryEntries) {
      _alertHistory.removeRange(_maxHistoryEntries, _alertHistory.length);
    }
    _currentAlert = event;
    _lastAlertType = event.type;
    _lastAlertTime = event.timestamp;

    if (settings != null) {
      AlertService.instance.triggerAlert(
        settings,
        type: event.type,
        confidence: event.confidence,
        severity: event.severity,
      );
    }
    notifyListeners();
    unawaited(_saveAlertHistory());
    return true;
  }

  void dismissAlert() {
    if (_currentAlert != null) {
      final idx = _alertHistory.indexWhere((a) => a.id == _currentAlert!.id);
      if (idx != -1) {
        _alertHistory[idx] = _alertHistory[idx].copyWith(dismissed: true);
        unawaited(_saveAlertHistory());
      }
    }
    _currentAlert = null;
    notifyListeners();
  }

  void clearHistory() {
    _alertHistory.clear();
    _currentAlert = null;
    unawaited(_saveAlertHistory());
    notifyListeners();
  }

  @override
  void dispose() {
    _soundService.stopMonitoring();
    unawaited(_bridge.dispose());
    AlertService.instance.stopAll();
    super.dispose();
  }
}
