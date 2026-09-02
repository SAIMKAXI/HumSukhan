# Changelog

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
