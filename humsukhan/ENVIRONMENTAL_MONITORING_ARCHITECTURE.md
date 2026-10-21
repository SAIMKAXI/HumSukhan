# Environmental monitoring architecture

Everything lives in `lib/modules/environmental_alerts/`. Each rule has one
home; if you need to change one, there is exactly one place to do it.

| Concern | Owner |
|---|---|
| Which sounds exist, their AudioSet labels, threshold, severity, description | `models/environmental_sound.dart` |
| Status and failure causes, with the sentence shown for each | `models/monitoring_status.dart` |
| PCM chunks → 3 s windows every 1 s | `services/pcm_window_accumulator.dart` |
| Model output → alerts (exact labels, thresholds, 30 s per-sound cooldown) | `services/sound_alert_policy.dart` |
| Loading and running CED-Tiny | `services/sound_classifier.dart` |
| PCM in, alerts out | `services/sound_detection_engine.dart` |
| Per-sound switches, history, notification + vibration | `services/environmental_alert_pipeline.dart` |
| Who owns the microphone on this platform | `services/environmental_monitor.dart` |

## Pipeline

Microphone → 16 kHz mono PCM16 → 3 s window / 1 s hop → RMS gate →
local sherpa-onnx CED-Tiny INT8 → `SoundAlertPolicy` → `EnvironmentalAlertPipeline`
(switch check → history → notification + vibration) → screen (banner, screen
flash, torch).

Labels are matched **whole**. Matching by substring turned "Water tap, faucet"
and "Engine knocking" into knocks and "Wind chime" into a doorbell.

The model is copied out of the app bundle and loaded locally; monitoring never
touches the network and no audio is stored or uploaded. sherpa-onnx bindings are
initialised in whichever isolate loads the model — without that, the model can
never load.

## Android

`EnvironmentalMonitoringService` is a microphone foreground service and the
single owner of the monitoring state, which it keeps in memory in
`EnvironmentalMonitoringState`. A killed process therefore reads as OFF rather
than leaving a stale STARTING behind. Only the user's intent is persisted, so a
sticky restart resumes monitoring only if it was on.

Start-up is gated step by step: foreground notification (STARTING) → headless
Flutter engine runs `environmentalMonitoringBackgroundMain`, which loads the
model and answers READY → microphone opened → Dart confirms PCM is arriving →
ACTIVE. Audio that stops arriving for 5 s while active, or a start that does not
reach ACTIVE within 15 s, tears the service down and reports ERROR with a cause.

Detection and announcement happen in the service's Dart isolate, so alerts are
announced (notification + vibration) and recorded whether or not the app is
open. An open app is told about each alert so it can show the banner, flash the
screen and pulse the torch.

The Quick Settings tile and the app call the same start/stop on the same state.

## iOS

`InAppMonitor` records with the `record` plugin inside the app and keeps going
in the background through the `audio` background mode. iOS has no equivalent of
the Quick Settings tile; a Control Center control would need its own signed
widget extension target.

## Foreground speech

Speech recognition and environmental monitoring cannot share the microphone.
Starting Everyday Mode calls `EnvironmentalMonitoring.releaseForForegroundSpeech()`,
which stops monitoring on both platforms; the Alerts screen then shows it as off.
