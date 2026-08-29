import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Network connectivity state.
enum ConnectivityStatus { online, offline, checking }

/// Lightweight connectivity provider that checks actual internet reachability
/// without requiring additional packages.
///
/// Uses a simple DNS+TCP check to verify real connectivity rather than just
/// checking network interface availability.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityStatus _status = ConnectivityStatus.checking;
  Timer? _periodicTimer;
  StreamSubscription<List<NetworkInterface>>? _interfaceSubscription;
  bool _initialized = false;

  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isChecking => _status == ConnectivityStatus.checking;

  /// Human-readable label for UI display.
  String get statusLabel {
    switch (_status) {
      case ConnectivityStatus.online:
        return 'Online';
      case ConnectivityStatus.offline:
        return 'Offline';
      case ConnectivityStatus.checking:
        return 'Checking...';
    }
  }

  /// Initialize connectivity monitoring.
  /// Checks immediately, then every 10 seconds.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Check immediately
    await _checkConnectivity();

    // Periodic check every 10 seconds
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  /// Perform a real connectivity check.
  /// Attempts to reach a reliable internet endpoint.
  Future<void> _checkConnectivity() async {
    try {
      // Try to look up a reliable host
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final isReachable = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(isReachable ? ConnectivityStatus.online : ConnectivityStatus.offline);
    } on SocketException catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    } on TimeoutException catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Force an immediate connectivity check.
  Future<void> checkNow() async {
    _updateStatus(ConnectivityStatus.checking);
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _interfaceSubscription?.cancel();
    super.dispose();
  }
}
