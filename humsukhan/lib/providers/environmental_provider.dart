import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../modules/environmental_alerts/models/monitoring_status.dart';
import '../modules/environmental_alerts/services/alert_history_store.dart';
import '../modules/environmental_alerts/services/environmental_monitor.dart';
import '../services/alert_service.dart';
import 'settings_provider.dart';

/// What the Alerts screen shows: whether monitoring is running, why it is
/// not, the alert in front of the user and the history behind it.
///
/// It does not detect or announce anything itself. The platform monitor does
/// that wherever the audio is, and this provider follows it, adding the
/// effects that need the app on screen: the banner, screen flash and torch.
class EnvironmentalProvider extends ChangeNotifier {
  EnvironmentalProvider({
    EnvironmentalMonitor? monitor,
    AlertHistoryStore? history,
    Future<PermissionStatus> Function()? requestMicrophone,
    void Function(SoundEvent event, SettingsProvider? settings)? showInAppAlert,
  })  : _monitor = monitor ?? EnvironmentalMonitoring.instance,
        _history = history ?? AlertHistoryStore(),
        _requestMicrophone = requestMicrophone ?? Permission.microphone.request,
        _showInAppAlert = showInAppAlert ?? _flash {
    _subscription = _monitor.updates.listen(_onUpdate);
    unawaited(_monitor.attach().then((_) => _sync()));
    unawaited(_reloadHistory());
  }

  final EnvironmentalMonitor _monitor;
  final AlertHistoryStore _history;
  final Future<PermissionStatus> Function() _requestMicrophone;
  final void Function(SoundEvent, SettingsProvider?) _showInAppAlert;
  late final StreamSubscription<MonitorUpdate> _subscription;

  MonitoringStatus _status = MonitoringStatus.off;
  MonitoringFailure? _failure;
  List<SoundEvent> _alertHistory = const [];
  SoundEvent? _currentAlert;
  SettingsProvider? _settingsProvider;
  bool _busy = false;
  bool _disposed = false;

  void setSettingsProvider(SettingsProvider settings) => _settingsProvider = settings;

  bool get monitoringEnabled => _status == MonitoringStatus.active;
  bool get isStarting => _status == MonitoringStatus.starting;
  bool get isStopping => _status == MonitoringStatus.stopping;
  bool get hasError => _failure != null;
  bool get isProcessing => monitoringEnabled;
  String? get errorMessage => _failure?.message;

  /// Why monitoring is not running, for screens that show it localized.
  MonitoringFailure? get failure => _failure;

  /// The remedy for the current failure is in the system's app settings.
  bool get needsSystemSettings => _failure?.needsSystemSettings ?? false;

  /// Newest first.
  List<SoundEvent> get alertHistory => List.unmodifiable(_alertHistory);
  SoundEvent? get currentAlert => _currentAlert;

  Future<void> toggleMonitoring() async {
    if (_disposed || _busy || _status.isTransitioning) return;
    _busy = true;
    try {
      if (monitoringEnabled) {
        await _monitor.stop();
      } else {
        await _start();
      }
    } finally {
      _busy = false;
      _sync();
    }
  }

  Future<void> _start() async {
    _failure = null;
    final permission = await _requestMicrophone();
    if (_disposed) return;
    if (!permission.isGranted) {
      _status = MonitoringStatus.error;
      _failure = permission.isPermanentlyDenied
          ? MonitoringFailure.microphoneBlocked
          : MonitoringFailure.microphoneDenied;
      notifyListeners();
      return;
    }
    _status = MonitoringStatus.starting;
    notifyListeners();
    await _monitor.start();
  }

  Future<void> openMicrophoneSettings() => openAppSettings();

  /// Dismisses [id], or the alert on the banner when no id is given.
  Future<void> dismissAlert([String? id]) async {
    final target = id ?? _currentAlert?.id;
    if (_disposed || target == null) return;
    if (_currentAlert?.id == target) _currentAlert = null;
    _alertHistory = [
      for (final event in _alertHistory) event.id == target ? event.copyWith(dismissed: true) : event,
    ];
    notifyListeners();
    _setHistory(await _history.markDismissed(target));
  }

  Future<void> clearHistory() async {
    if (_disposed) return;
    _alertHistory = const [];
    _currentAlert = null;
    notifyListeners();
    _setHistory(await _history.clear());
  }

  void _onUpdate(MonitorUpdate update) {
    if (_disposed) return;
    final alert = update.alert;
    if (alert != null) {
      // With visual alerts off the alert still reaches history, but no
      // banner covers the screen.
      if (_settingsProvider?.visualAlerts ?? true) _currentAlert = alert;
      _showInAppAlert(alert, _settingsProvider);
      // The monitor has already recorded it; pick up that write.
      unawaited(_reloadHistory());
    }
    _sync();
  }

  /// Mirrors the monitor, except that a permission failure found here stays
  /// on screen until the user tries again.
  void _sync() {
    if (_disposed) return;
    final permissionFailure = _failure == MonitoringFailure.microphoneDenied ||
        _failure == MonitoringFailure.microphoneBlocked;
    if (permissionFailure && _monitor.status.canStart) {
      notifyListeners();
      return;
    }
    _status = _monitor.status;
    _failure = _status == MonitoringStatus.error ? (_monitor.failure ?? MonitoringFailure.service) : null;
    notifyListeners();
  }

  Future<void> _reloadHistory() async => _setHistory(await _history.load());

  void _setHistory(List<SoundEvent> events) {
    if (_disposed) return;
    _alertHistory = events;
    notifyListeners();
  }

  static void _flash(SoundEvent event, SettingsProvider? settings) {
    AlertService.instance.flash(
      event.severity,
      screen: settings?.screenFlashAlerts ?? true,
      flashlight: settings?.flashAlerts ?? false,
    );
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Leaves monitoring running: it is the user's choice, not this screen's,
  /// and the provider is rebuilt whenever the signed-in account changes.
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    AlertService.instance.stopAll();
    super.dispose();
  }
}
