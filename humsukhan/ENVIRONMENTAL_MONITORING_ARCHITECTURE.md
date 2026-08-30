# Environmental monitoring architecture

The environmental monitor uses one authoritative native monitoring state on each platform and a single Flutter environmental pipeline.

## Pipeline

Microphone → 16 kHz mono PCM16 → RMS gate → 3 s window / 1 s hop → local sherpa-ONNX CED-Tiny INT8 → confidence filtering → temporal confirmation → severity → EnvironmentalProvider → AlertService.

The ONNX model is loaded only while monitoring is active. No raw environmental audio is uploaded or retained.

## Android

`EnvironmentalMonitoringService` is the long-running foreground owner. `EnvironmentalMonitoringTileService` is the explicit Quick Settings entry point. The Flutter UI requests the same native start/stop operation; it does not maintain a second background flag.

A tile start is a user interaction with the system tile, so the service remains independent of the Flutter Activity lifecycle. Android's microphone foreground-service requirements still apply, and microphone permission must already have been granted before a background microphone service can start on modern Android.

## iOS

The Flutter app uses a native method-channel bridge and an audio background mode where permitted. iOS does not have an Android-style arbitrary tile API. A future WidgetKit Control extension can call the same shared native state, but it must be added as a signed Xcode widget/control target; the Flutter Runner target alone cannot manufacture a Control Center module.

## Offline behavior

Model initialization is local-only. Monitoring never waits for network connectivity. Model download is a separate setup operation and failure leaves monitoring OFF rather than claiming that a local model exists.
