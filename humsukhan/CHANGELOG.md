# Changelog

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
