# HumSukhan

**An accessibility-first communication companion for Deaf and Hard-of-Hearing people.**

HumSukhan (هم سخن, *one who speaks with you*) helps people who are Deaf or Hard of Hearing follow everyday conversations, capture lectures and meetings, and notice important sounds around them, in English and Urdu.

[Download the latest Android release](https://github.com/SAIMKAXI/HumSukhan/releases/latest)

---

## What it does

### Everyday conversations
- **Live captions** of the person in front of you, in English and Urdu, with the language detected automatically. Urdu is always shown in Urdu script, including speech the recognizer hears as Roman Urdu.
- **Reply** by typing, by having the app speak your text aloud, or with one tap on a **quick reply**. Quick replies can be added, starred and deleted; starred ones come first.
- A natural pause ends a caption and listening continues. The pause length is adjustable, or captions can be ended by hand.
- **Conversations are temporary.** Nothing is saved once the conversation ends.

### Professional sessions
- Record **meetings, lectures and classes** as live transcripts, in English, Urdu or Auto.
- Organise sessions in **folders**. Each session is kept for **1, 7 or 15 days** and then deleted.
- **AI insights** for a finished session: summary bullets, action items, deadlines and the people mentioned.
- **Export** a session as a text file, or copy it to the clipboard.
- **Transcripts and folders stay on the phone.**

### Environmental alerts
- Detects **sirens, doorbells and knocks** on the phone, with no network.
- Announces each alert with a **notification and vibration**, including when the app is closed. With the app open it also shows a banner, flashes the screen and can pulse the camera flashlight.
- On Android, monitoring runs as a foreground service and can be switched from a **Quick Settings tile**.

### Wellbeing
- **Optional mood check-ins**: five faces, optional words such as "tired" or "left out", and an optional private note. A gentle reminder once or twice a day, at times the user picks, if they want one.
- **Your own pattern**: a 7- and 30-day chart, compared with your usual level rather than a plain average. HumSukhan never diagnoses.
- **Get help**: pre-written ideas in Urdu and English (or both side by side), chosen by how the last few days have gone, with a read-aloud button. They include a breathing guide you can follow by sight.
- The lowest mood, or words about self-harm in a note, opens a fixed help screen instead, with a large message to show to someone nearby.
- **Check-ins stay on the phone.** They are never uploaded, and are left out of Android backups.

### Accessibility and settings
- Light, dark and a dedicated **high-contrast** theme; large text on top of the system text size; adjustable caption size.
- English and Urdu interface, with right-to-left layout and Nastaliq script for Urdu.
- Every alert channel can be switched on or off: vibration, visual alerts, screen flash and flashlight, and each sound individually.

## How speech works

**Speech to text** tries recognizers in order and moves on when one cannot start or stops producing captions:

| Caption language | Order |
|---|---|
| English or Urdu | Phone's own recognizer (if the language is installed) → Deepgram live stream → cloud per-sentence recognition → offline model |
| Auto (English + Urdu) | Deepgram live stream with English and Urdu side by side → cloud per-sentence recognition → phone recognizer → offline model |

- With no internet connection the cloud steps are skipped.
- If the live stream goes quiet, the next recognizer takes over. That means a microphone sending only silence, or about 10 seconds of speech with no words back.
- **Offline models** are downloaded once in Settings: English (streaming, 73 MB) and Urdu (Whisper base, 161 MB, one sentence at a time).

**Text to speech** uses the phone's own voice when it has one for the language, and otherwise a cloud voice: Deepgram for English, Soniox for Urdu.

## Privacy

| Data | Where it lives |
|---|---|
| Conversational transcripts | Nowhere; never saved |
| Professional transcripts and folders | On the phone only |
| Account, profile, settings, quick replies | Supabase, readable only by their owner |
| AI insights | Supabase, deleted when their session expires |
| Environmental audio | Processed on the phone; never stored or uploaded |
| Wellbeing check-ins and notes | On the phone only; not uploaded, and excluded from Android cloud backup and device transfer |

Audio is sent to Deepgram only while cloud speech recognition is in use. A session's transcript is sent to Gemini only to generate its insights. Neither is stored by HumSukhan.

## Technology

- **App:** Flutter (Dart), Provider for state, with native Android (Kotlin) code for the monitoring service and Quick Settings tile.
- **On-device AI:** [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) runs the CED-Tiny sound classifier and the offline speech models.
- **Speech:** the Android and iOS speech recognizers, [Deepgram](https://deepgram.com) (streaming and batch recognition, English voice) and [Soniox](https://soniox.com) (Urdu voice).
- **AI insights:** Google Gemini Flash.
- **Backend:** [Supabase](https://supabase.com): authentication, Postgres with row-level security, and Edge Functions that hold every API key, so none ships in the app.

## Repository layout

```
humsukhan/            Flutter app
  lib/
    screens/          Screens (home, everyday, professional, alerts, settings, auth)
    providers/        App state (speech, conversation, professional, settings, ...)
    services/         Speech, AI, database and platform services
    modules/environmental_alerts/   Sound detection and monitoring
    l10n/             English and Urdu strings
  android/            Android app, monitoring service and Quick Settings tile
  ios/                iOS app
  test/               Unit and widget tests
supabase/
  functions/          Edge Functions
  migrations/         Database schema
docs/                 Architecture, design and guidelines
```

## Building

Requirements: Flutter 3.47 (Dart 3.8 or later) and an Android SDK. iOS builds need Xcode.

```bash
cd humsukhan
flutter pub get
bash tool/prepare_environmental_model.sh   # downloads the bundled sound model
flutter run --dart-define=SUPABASE_ANON_KEY=<your Supabase anon key>
```

HumSukhan requires an account, so the app needs `SUPABASE_ANON_KEY` (the project's public anon key) to sign in. The Edge Function secrets are set in Supabase, never in the app; they are listed in [docs/backend.md](docs/backend.md).

## Testing

```bash
flutter analyze
flutter test
```

Some tests run the real on-device models and are skipped unless the models are available locally; each test file explains how to enable it. Pull requests to `main` and pushes to `main` run analysis, the full test suite and an Android build.

## Documentation

- [Architecture](docs/architecture.md): how the app is put together
- [Environmental alerts](docs/environmental-alerts.md): sound detection and the monitoring service
- [Backend](docs/backend.md): Supabase tables, Edge Functions and secrets
- [Design](docs/design.md): the design system and screens
- [Guidelines](docs/guidelines.md): experience principles and engineering rules
- [Releasing](docs/releasing.md): signing and publishing Android releases
