# Changelog

## 2.4.4+34

### Environmental Alerts
- Android background monitoring now captures 16 kHz mono PCM natively with `AudioRecord` instead of relying on the Flutter recorder inside the background engine.
- Actual PCM delivery is forwarded through the existing environmental MethodChannel so the local Sherpa ONNX classifier receives real microphone samples while monitoring runs in the background.
- Added audio-flow watchdog/observability and stronger regression coverage around the native capture handoff and 3-second inference windows.

### Reliability
- Preserved the fully local bundled environmental model path introduced in v2.4.3 while replacing the Android background audio transport with the native capture path.

## 2.4.1+31

### Everyday Mode
- A pause now ends the current utterance instead of closing the microphone, so speaking continuously produces one caption per utterance rather than stopping after the first.
- Captions no longer repeat the first recognised phrase. Committing a turn read a leftover transcript from a different speech service that Everyday Mode never runs, and that stale text replaced every new caption.
- Speaking again before the pause elapses no longer discards the previous utterance.

### Professional Mode
- A dropped recognizer connection is now detected and reconnected. Previously the microphone kept streaming into a closed socket, the screen still showed "Listening…", and no further captions could arrive.
- AI summary failures now say what went wrong and show a distinct loading state, instead of looking identical to a session that simply has no summary.

### Environmental Alerts
- A truncated sound-model download is now rejected instead of being stored as if complete, and an unusable cached model is discarded so the next attempt re-downloads it. Previously a bad download left monitoring permanently unable to start.

### Speech and audio
- The device speech-capability check no longer plays audible sound. It ran on app resume whenever a voice was missing (the normal case for Urdu), which made the app appear to speak on its own after sign-in.

### Branding
- Restored the green brand treatment behind the in-app logo and matched its framing to the launcher icon.
- Corrected the Android launcher label to "HumSukhan".

### Android
- Declared the speech recognition service query required by Android 11+ package visibility, without which the device recognizer is invisible to the app.

## 2.4.0+30

### Speech reliability
- Fixed a stale-negative capability cache: a device whose speech recognizer was already available but was missing a language pack (e.g. Urdu) at first launch now rediscovers that language after the pack is installed and the app resumes, instead of staying permanently marked unavailable.
- Fixed the Speak button failing silently when both native and cloud text-to-speech are unavailable; the failure now surfaces as a visible message instead of doing nothing.
- Closed two start-listening race conditions (a rapid double-tap on the mic, and a stop called while a start was still in flight) that could open duplicate microphone/socket sessions.
- Removed a dead, unused duplicate `SpeechProvider` implementation that two of the app's own regression tests were unknowingly validating instead of the real one; those tests now exercise the actual production speech provider.

### Branding
- Replaced the app icon and in-app logo with the current HumSukhan mark across Android (adaptive icon foreground/background/monochrome layers, all legacy launcher densities) and iOS (`AppIcon.appiconset`, all required sizes).
- Fixed a build-breaking regression where the Android adaptive icon referenced a themed/monochrome icon resource that didn't exist.
- Fixed the in-app brand logo badge (nav bar, app bar, auth, splash, settings) rendering with a doubled frame at small sizes; it now uses a dedicated mark-only asset instead of the full lockup.
- Settings screen now renders its header logo consistently with the rest of the app.

## 2.3.1+20

### Speech stack reliability
- Keep the Deepgram streaming WebSocket alive across microphone turns to remove repeated connection setup latency.
- Stop sending microphone frames before finalization and wait for the provider final result instead of relying on a fixed short delay.
- Preserve the final buffered transcript when a streaming provider does not emit an explicit speech-final packet.
- Route normal online English, Urdu, Roman Urdu, Hindi, and Auto live sessions through the streaming path; explicit Sherpa modes remain available for offline operation.

### Speech playback
- Prefer installed device voices for immediate English, Urdu, and Hindi playback.
- Keep cloud TTS as the language-capability fallback instead of paying the cloud round-trip on every normal English Speak action.
- Add a small in-memory cloud audio cache for repeated captions.
- Detect Devanagari Hindi separately so Hindi captions are not incorrectly routed as English or Urdu.

### Regression coverage
- Added language-detection coverage for Hindi, Urdu, Roman Urdu, and English.
- Existing application UI, data, authentication, environmental monitoring, and offline model features remain unchanged.
