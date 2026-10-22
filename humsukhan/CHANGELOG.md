# Changelog

## Unreleased

## 2.4.9+39

### Installing
- A permanent Android signing key is not configured for this release. CI therefore uses its runner's debug key. Because a later runner may use a different key, Android may reject this APK as an update to an existing installation. A permanent key is needed for reliable in-place updates. Uninstalling first can erase device-local Professional Mode sessions, transcripts, and folders, so preserve any needed data before uninstalling.

### Account
- Password reset emails now open the app to set the new password. They used to send the user to a `localhost` address.
- Editing the profile: an empty name is explained instead of silently ignored, a photo that cannot be opened is reported, and closing the editor no longer raises an error.

### Environmental Alerts
- Monitoring that captions stopped to free the microphone starts again when captioning ends. It used to stay off until switched on again.
- The Visual Alerts switch now works: off, alerts still vibrate and are kept in history, but there is no alert notification or banner. Before, it changed nothing.

### Professional Mode
- Removed the Roman Urdu speech language: it produced the same Urdu-script captions as Urdu. The choices are Auto, English and Urdu; sessions created with Roman Urdu keep working as Urdu.
- A new folder can be created when folders already exist. The button used to appear only while there were none.
- Creating a folder with a name already in use says so instead of doing nothing.
- The New session and Create folder dialogs no longer raise an error while closing.
- When the microphone cannot start, the screen shows the actual reason (for example, no connection and no offline model).

### Conversational Mode
- Leaving the screen clears the conversation without disturbing the screens being closed. The end-of-conversation screen is translated into Urdu.

## 2.4.8+38

### Privacy and Professional Mode
- Conversational Mode transcripts are temporary and are cleared when leaving the screen; they are no longer saved to device history or cloud storage.
- Professional Mode sessions, transcripts, and folders remain on the device. Reusable AI summaries, action items, deadlines, and mentioned people are cached in Supabase until the session retention deadline.
- Existing cached insights are checked before requesting AI generation again, avoiding duplicate model requests for sessions that already have a saved result.
- Retired the obsolete legacy insights endpoint; the current v2 endpoint remains the supported generation service.

### Speech to text
- Captions now come from the phone's own recognizer first when it has the language installed, then from the cloud, then from a downloaded offline model. In Auto (English and Urdu together) the cloud goes first, because a phone recognizer listens in one language only.
- With no internet connection the cloud is skipped, so captions start from the phone or the offline model without waiting out the cloud's timeouts.
- If the live cloud stream stops captioning, because the connection dropped, the microphone delivers only silence, or 10 seconds of speech came back with no words, the next recognizer takes over. Before, the screen could show "listening" indefinitely with nothing captioned.
- The phone's recognizer was judged to have failed before it had reported starting, so a second recognizer was opened on the same microphone.
- Speech recognition stops Environmental monitoring started from the Quick Settings tile before taking the microphone. It used to miss monitoring the app had not yet heard about.
- When the live stream fails in Auto, the backup still recognizes both English and Urdu. It used to fall back to English only.

### Urdu detection
- In Auto, Urdu speech that the English recognizer had written out as Roman Urdu is now shown from the Urdu recognizer, in Urdu script. Before, captions mixed both scripts (for example "آپ کیا کرنا chahte ہیں") and were labelled "Auto" instead of Urdu.

### Offline models
- The English model's download link pointed to a repository that does not exist, so the Download button always failed. It now downloads the English streaming model (73 MB).
- There is now an Urdu offline model: Whisper base, held to Urdu (161 MB). It recognizes each sentence after the speaker pauses, on a background isolate so the screen does not freeze.
- Download shows its progress and says why it failed. A cut-off file is detected instead of being taken for a model, and files already downloaded are not fetched again.
- A downloaded model is used from the next time listening starts, with nothing to set up. Before, it was only noticed after restarting the app.
- Downloads no longer break after the signed-in account changes.

### Quick replies
- With the app in Urdu, saved quick replies, and which were starred, were replaced by the defaults at every launch. They are kept now.
- The conversation row shows every quick reply, with favourites first and then your own, newest first. A newly added reply used to be hidden beyond the first six.

### Professional Mode
- AI summaries failed for every session: Google retired `gemini-2.5-flash` for this API key. `generate-insights-v2` now uses `gemini-3.5-flash`, then `gemini-3-flash-preview`, then `gemini-2.5-flash`.

## 2.4.7+37

### Environmental Alerts
- Rebuilt the detection and monitoring logic; the Alerts screen looks and works the same.
- The sound model can now load. It was created without initialising sherpa-onnx, which refuses to run until that is done, so detection failed to start.
- Sounds are matched to their exact model labels. A running tap, guitar tapping and an engine knocking no longer raise a Knock alert, and a wind chime no longer raises a Doorbell alert; a "ding-dong" doorbell is now recognised.
- Alerts are announced with a notification and vibration even while the app is closed. Previously a background alert only changed the text of the silent monitoring notification.
- An alert is announced once. With the app open, it used to vibrate twice.
- Monitoring can be started again after it is stopped (on iOS every start after the first failed).
- A monitor stopped by the system, or stalled mid-start, can no longer leave the Quick Settings tile stuck. Audio that stops arriving is detected at any point, not only at start-up.
- Each failure shows its own cause and remedy, and "Open microphone settings" appears exactly when settings can fix it.
- Alert history lists the newest alert first, and dismissing a history entry dismisses that entry.
- Removed the Baby Cry switch from Settings: that sound is not detected.

## 2.4.4+34

### Environmental Alerts
- Android background monitoring now captures 16 kHz mono PCM natively through `AudioRecord` instead of relying on the background `record` stream.
- PCM delivery to the background Flutter engine is monitored so monitoring cannot remain falsely marked active when audio stops flowing.
- Native capture and Dart handoff regression coverage was strengthened for background monitoring.

## 2.4.3+33

### Environmental Alerts
- Bundled the environmental sound model for fully local monitoring.
- Removed the retired Baby Cry alert from the supported alert catalog.

### Branding
- Standardized the HumSukhan launcher and onboarding branding on the canonical logo assets.
- Removed obsolete launcher and temporary logo resources.

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
