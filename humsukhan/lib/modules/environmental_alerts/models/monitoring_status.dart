/// Lifecycle of environmental monitoring, shared by every platform.
enum MonitoringStatus {
  off('OFF'),
  starting('STARTING'),
  active('ACTIVE'),
  stopping('STOPPING'),
  error('ERROR');

  const MonitoringStatus(this.wireName);

  /// Name used on the Android method/event channels.
  final String wireName;

  bool get isTransitioning => this == starting || this == stopping;

  /// Monitoring can be started from here; `error` means it is not running.
  bool get canStart => this == off || this == error;

  static MonitoringStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return off;
  }
}

/// Why monitoring is not running. Each failure carries the sentence shown to
/// the user, so a cause can never be reported with another cause's remedy.
enum MonitoringFailure {
  microphoneDenied(
    'MIC_DENIED',
    'Microphone permission is required for Environmental Alerts.',
  ),
  microphoneBlocked(
    'MIC_PERMISSION',
    'Microphone permission is blocked. Open App Settings and allow Microphone, then tap Start Monitoring again.',
    needsSystemSettings: true,
  ),
  microphoneUnavailable(
    'MIC_UNAVAILABLE',
    'Microphone access is unavailable. Allow microphone access in App Settings, then try again.',
    needsSystemSettings: true,
  ),
  model(
    'MODEL',
    'Environmental sound detection could not load its built-in local model. Please update or reinstall the app.',
  ),
  capture(
    'CAPTURE',
    'The microphone recorder could not start. Check microphone access and try again.',
  ),
  service(
    'SERVICE',
    'Environmental monitoring could not start. Check microphone permission and Android battery/background restrictions, then try again.',
  ),
  busy(
    'BUSY',
    'Environmental monitoring could not start safely because the background service is still changing state. Try again in a moment.',
  ),
  stopFailed(
    'STOP_FAILED',
    'Environmental monitoring could not be stopped safely. Try again.',
  );

  const MonitoringFailure(this.code, this.message, {this.needsSystemSettings = false});

  /// Code used on the Android method/event channels.
  final String code;
  final String message;
  final bool needsSystemSettings;

  /// Unknown or missing codes are reported as a service failure rather than
  /// dropped, so an error state always has a sentence to show.
  static MonitoringFailure fromCode(String? code) {
    for (final failure in values) {
      if (failure.code == code) return failure;
    }
    // The native side reports a lost audio stream as NO_AUDIO.
    return service;
  }
}
