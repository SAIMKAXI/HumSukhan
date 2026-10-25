# Architecture

HumSukhan is a Flutter app with native Android code for background sound monitoring, and a Supabase backend for accounts, settings and AI insights. This document describes how the pieces fit together.

## Overview

```
┌──────────────────────────── Flutter app ─────────────────────────────┐
│  Screens: Home · Everyday · Professional · Alerts · Settings · Auth   │
│                                                                      │
│  Providers (state)                                                   │
│    SpeechProvider: speech to text and text to speech, all modes      │
│    ConversationProvider · ProfessionalProvider · EnvironmentalProvider│
│    SettingsProvider · UserProvider · QuickReplyProvider · Auth       │
│                                                                      │
│  Services                                                            │
│    Speech: phone recognizer · Deepgram stream · cloud per-sentence · │
│            sherpa-onnx offline models · phone and cloud voices       │
│    AI insights · Supabase database · notifications · alerts          │
│    Environmental alerts module (sound classifier, monitor, pipeline) │
└──────────┬──────────────────────────────────────────┬────────────────┘
           │ MethodChannel / EventChannel             │ HTTPS
┌──────────▼───────────── Android ─────────┐  ┌───────▼──────── Supabase ─────────┐
│ EnvironmentalMonitoringService           │  │ Auth                               │
│   (microphone foreground service,        │  │ Postgres: profiles, settings,      │
│    headless Flutter engine)              │  │   quick_replies, insights (RLS)    │
│ Quick Settings tile                      │  │ Edge Functions: Deepgram, speech   │
│ Flashlight channel                       │  │   synthesis, Gemini, accounts      │
└──────────────────────────────────────────┘  └────────────────────────────────────┘
```

State is held in `ChangeNotifier` providers (`provider` package), created once in `main.dart` and rebuilt when the signed-in account changes. Screens read them; services do the work.

## Code layout

| Path (under `humsukhan/lib/`) | Contents |
|---|---|
| `main.dart` | App start-up, themes, providers, account gate, app lifecycle handling, and the Android monitoring service's Dart entry point |
| `screens/` | One file per screen |
| `widgets/` | Reusable widgets: caption bubbles, quick reply chips, cards, badges |
| `providers/` | App state |
| `services/` | Speech, AI, database, notification and alert services |
| `services/stt/` | Speech-to-text engines, the recognizer order (`stt_plan.dart`) and offline models |
| `modules/environmental_alerts/` | Sound detection and monitoring; see [environmental-alerts.md](environmental-alerts.md) |
| `l10n/app_strings.dart` | Every user-facing string, in English and Urdu |
| `theme/` | Design tokens and themes |
| `models/models.dart` | Data models: captions, sessions, folders, insights, quick replies, sound events |

## Speech to text

`EverydaySpeechProvider` (exposed to the app as `SpeechProvider`) serves both Everyday and Professional Mode. When listening starts it:

1. Frees the microphone from environmental monitoring. If monitoring was on, it starts again a few seconds after listening ends.
2. Checks whether the cloud can be used: a signed-in account and a reachable network.
3. Builds a plan with `sttPlan()` and starts the first recognizer that works.

| Caption language | Plan |
|---|---|
| English or Urdu | phone recognizer (if the language is installed) → Deepgram live stream → cloud per-sentence → offline model |
| Auto | Deepgram live stream, English and Urdu → cloud per-sentence, bilingual → phone recognizer → offline model |

The steps:

- **Phone recognizer.** `speech_to_text`, using the locale the device reports as installed.
- **Deepgram live stream** (`EverydayBilingualSttService`). A WebSocket per language, authorised with a short-lived token from the `deepgram-token` Edge Function. In Auto mode the English and Urdu streams run side by side, and their transcripts are compared segment by segment. Roman Urdu coming from the English recognizer is taken as evidence that Urdu was spoken, so the Urdu transcript is shown.
- **Cloud per-sentence** (`CloudChunkStt`). Records until the speaker pauses and sends each sentence to `deepgram-transcribe` or `deepgram-transcribe-bilingual`.
- **Offline models** (`SherpaSTTProvider`). English uses a streaming Zipformer. Urdu uses Whisper base held to Urdu, run on a background isolate one sentence at a time. Both are downloaded in Settings by `ModelManager`, checked against their expected sizes, and used without a restart.

Starting is kept under a second. The Deepgram token lasts an hour and is fetched once, ahead of the first tap, and shared by both streams. The two streams connect at the same time, and the microphone opens while they connect, so what is said meanwhile is sent once they are open. Freeing the microphone from monitoring, checking the network and loading the phone recognizer run side by side. Stopping closes the microphone at once and waits at most 300 ms for words the recognizers still hold.

A `CaptionWatchdog` watches the live stream. A microphone delivering only silence for 3 seconds, or 10 seconds of speech with no words back, counts as a failed stream, and the next step of the plan takes over. A dropped connection that cannot reconnect is handled the same way. Only if no step can start is the screen told that listening stopped, with the reason.

## Text to speech

`ResilientTtsProvider` speaks with the phone's own voice when it has one for the language. Otherwise it uses the `speech-synthesis` Edge Function (Deepgram for English, Soniox for Urdu), then `speech-synthesis-v2`. Mixed English and Urdu text is split into runs and each run is spoken in its own language. While a reply is being spoken, listening pauses and then resumes.

## Everyday Mode

`ConversationEngine` turns speech results into a conversation. Each result updates the current caption as soon as it arrives, a natural pause commits it, and listening continues for the next sentence. While a conversation is open, environmental monitoring stays paused between turns and resumes 20 seconds after the last one, or 3 seconds after the conversation ends, so each tap on the microphone does not wait for the monitoring service to stop. The pause length is configurable, or captions can be ended by hand. `ConversationProvider` holds the captions in memory only: a conversation is discarded when it ends or the screen is left.

## Professional Mode

`ProfessionalProvider` keeps sessions, folders and cached insights in local storage, scoped to the signed-in account. Sessions expire after their retention period (1, 7 or 15 days); expiry deletes the session and its insight on the phone and in Supabase.

AI insights come from the `generate-insights-v2` Edge Function, which sends the transcript to Gemini Flash and returns summary bullets, action items, deadlines and mentioned people. The result is cached on the phone and in the `insights` table until the session expires. Opening a session again reuses it instead of generating it again.

## Accounts and settings

- **Sign-up** goes through the `create-account` Edge Function, which will not overwrite an existing account. Sign-in, sign-out and password reset use Supabase Auth.
- **Password reset** emails link back into the app through the `com.humsukhan.humsukhan://login-callback/` deep link.
- **Settings** are stored on the phone and mirrored to the `settings` table, so they follow the account.
- **Profile and quick replies** are stored in `profiles` and `quick_replies` and kept on the phone as well.
- **Built-in quick replies** are translated when the app language changes. The user's own replies and stars are kept.

## Environmental alerts

Sound detection runs on the phone with the CED-Tiny audio-tagging model. On Android it runs inside a microphone foreground service, so it keeps working with the app closed. See [environmental-alerts.md](environmental-alerts.md).

## Backend

Every API key lives in Supabase Edge Function secrets; the app holds only the public anon key. Tables, functions and secrets are described in [backend.md](backend.md).

## Testing and CI

`humsukhan/test/` holds unit and widget tests for the providers, the speech plan and its hand-over, the watchdog and the bilingual arbitration. It also has tests for the offline model downloads, environmental monitoring on both platforms, and smoke tests that operate every control in Settings. Tests that need real models run only when the models are available locally.

The **HumSukhan Flutter QA** workflow runs `flutter analyze`, `flutter test` and an Android build on pull requests and on `main`. **HumSukhan Android Release** builds and publishes the release APK; see [releasing.md](releasing.md).
