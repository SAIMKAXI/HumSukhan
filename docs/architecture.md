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
| `modules/wellbeing/` | Mood check-ins: storage, pattern rules, reminders and the pre-written support library |
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
- **Deepgram live stream** (`EverydayBilingualSttService`). A WebSocket per language, authorised with a short-lived token from the `deepgram-token` Edge Function. Audio comes from Android's speech-recognition microphone source, which skips the gain and noise processing that blurs consonants. In Auto mode the English and Urdu streams run side by side, and their transcripts are compared segment by segment:
  - Roman Urdu from the English recognizer is taken as evidence that Urdu was spoken, so the Urdu transcript is shown.
  - Urdu speech is full of short function words (ہے، کے، کہ، نہیں …); English written out in Urdu letters has none. An Urdu segment with them is preferred, one without them is not.
  - Within an utterance, the language of the part before tips a close call.
  - Both recognizers hear the same audio, so the slower one's copy of an utterance already shown is dropped.
- **Cloud per-sentence** (`CloudChunkStt`). Records until the speaker pauses and sends each sentence to `deepgram-transcribe` or `deepgram-transcribe-bilingual`.
- **Offline models** (`SherpaSTTProvider`). English uses a streaming Zipformer. Urdu uses Whisper base held to Urdu, run on a background isolate one sentence at a time. Both are downloaded in Settings by `ModelManager`, checked against their expected sizes, and used without a restart.

Starting is kept under a second. The Deepgram token lasts an hour and is fetched once, ahead of the first tap, and shared by both streams. The two streams connect at the same time, and the microphone opens while they connect, so what is said meanwhile is sent once they are open. Freeing the microphone from monitoring, checking the network and loading the phone recognizer run side by side. Stopping closes the microphone at once and waits at most 300 ms for words the recognizers still hold.

A `CaptionWatchdog` watches the live stream. A microphone delivering only silence for 3 seconds, or 10 seconds of speech with no words back, counts as a failed stream, and the next step of the plan takes over. A dropped connection that cannot reconnect is handled the same way. Only if no step can start is the screen told that listening stopped, with the reason.

## Text to speech

`ResilientTtsProvider` speaks with the phone's own voice when it has one for the language. Otherwise it uses the `speech-synthesis` Edge Function (Deepgram for English, Soniox for Urdu), then `speech-synthesis-v2`. Mixed English and Urdu text is split into runs and each run is spoken in its own language. While a reply is being spoken, listening pauses and then resumes.

## Everyday Mode

`ConversationEngine` turns speech results into a conversation. Each result updates the current caption as soon as it arrives, a pause commits it, and listening continues for the next sentence.

How long a pause has to be is decided by rules in `turn_taking.dart`, not a fixed timer. They read the words said so far, in English, Urdu and Roman Urdu:

| The words end… | Example | The caption ends after |
|---|---|---|
| as a finished sentence | "I am going home now." · "میں کل آؤں گا۔" | about half the chosen pause (at least 0.6 s) |
| either way | "maybe tomorrow" | the chosen pause |
| mid-sentence | "…and" · "…the" · "…کہ" · "…کے" · "um" · "…" | 1.8 × the chosen pause (at most 4.5 s) |

- Each speaker's own pauses are learned during the conversation, so someone who stops longer to think is given longer.
- A sound from the speaker during a pause (Deepgram's speech-started event) keeps the caption open, at most twice, so a noisy room cannot hold it open.
- Speech after a hesitation carries on the same sentence, and the full stop the recognizer put at the pause is removed. Speech after a finished sentence starts a new sentence in the same caption.

The microphone and the speaker never run at the same time: while a reply is spoken aloud the microphone is off, or the app would caption its own voice. Everything else works while the speaker talks. Typing, quick replies and Speak are available with the microphone on: what the speaker said so far becomes their caption, the reply follows it, and listening carries on by itself after a spoken reply. While a conversation is open, environmental monitoring stays paused between turns and resumes 20 seconds after the last one, or 3 seconds after the conversation ends, so each tap on the microphone does not wait for the monitoring service to stop. The pause length is configurable, or captions can be ended by hand. `ConversationProvider` holds the captions in memory only: a conversation is discarded when it ends or the screen is left.

## Professional Mode

The microphone stays on for the whole recording; nothing is spoken aloud. The recognizer ends a piece at every pause, so a piece that ends mid-sentence is held, for up to 3 seconds, and joined to the next one (`SentenceAssembler`), and the transcript keeps whole sentences.

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

## Wellbeing

Optional mood check-ins, reached from the Home screen (`/wellbeing`). `WellbeingProvider` holds them for the signed-in account. Nothing in this feature talks to the server.

- **Storage** (`MoodStore`). One JSON file per account in the app's private `files/wellbeing/` folder. Writes go to a temporary file that then replaces the old one, one at a time. A damaged file is set aside and reported, not overwritten. `res/xml/backup_rules.xml` and `res/xml/data_extraction_rules.xml` leave that folder out of cloud backup and device transfer; everything else is backed up as before. Check-ins older than 400 days are dropped.
- **Pattern** (`MoodPatterns`). Rules, all in one file, compare recent check-ins with the user's own usual level:

  | State | When |
  |---|---|
  | Urgent | The latest check-in is the lowest mood, or its note mentions self-harm (`CrisisWords`: English, Urdu, Roman Urdu) |
  | Several low days | Three low check-ins in a row within a week, or the last 3 days average at least 1 point below the 14 days before, and no higher than "okay" |
  | Low day | The latest check-in is low |
  | Doing well / steady | Otherwise, by the latest check-in |

  A check-in older than 36 hours says nothing about now.
- **Support** (`SupportLibrary`). Fixed, pre-written items in English and Urdu for each state, shown in the app language or both. Nothing is generated. The urgent state always gets the fixed help screen: safety steps, a full-screen message in both languages for the user to show someone nearby, and a breathing guide that works by sight.
- **Reminders** (`ReminderPlan`, `LocalNotificationReminders`). Off until the user turns them on. Once a day at 20:00 by default, or twice; the times can be changed. They are scheduled as single notifications over the next two weeks, rescheduled whenever the app opens or a check-in is saved, so a slot already checked in for is skipped and reminders stop if the app goes unused. Inexact alarms, so no exact-alarm permission. The plugin's boot receiver restores them after a restart or update. Tapping one opens the check-in.

## Backend

Every API key lives in Supabase Edge Function secrets; the app holds only the public anon key. Tables, functions and secrets are described in [backend.md](backend.md).

## Testing and CI

`humsukhan/test/` holds unit and widget tests for the providers, the speech plan and its hand-over, the watchdog and the bilingual arbitration. It also has tests for the offline model downloads, environmental monitoring on both platforms, and smoke tests that operate every control in Settings. Tests that need real models run only when the models are available locally.

The **HumSukhan Flutter QA** workflow runs `flutter analyze`, `flutter test` and an Android build on pull requests and on `main`. **HumSukhan Android Release** builds and publishes the release APK; see [releasing.md](releasing.md).
