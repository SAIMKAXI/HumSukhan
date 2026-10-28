# HumSukhan — Experience and Engineering Guidelines

Two audiences in one document:

- **§1–4** the intended user experience, end to end.
- **§5–6** the engineering rules every change follows.

---

## 1. Principles

1. **The user may not hear anything.** Never rely on sound to communicate state.
   An audible-only error is no error at all.
2. **Never silently do nothing.** Every control either acts, recovers, or says
   why it can't — in words, on screen.
3. **Honesty over optimism.** "Urdu voice not installed on this device" beats a
   button that appears to work and doesn't.
4. **The transcript is the product.** Losing recognised speech is the worst
   possible bug. Prefer duplicated text over dropped text.
5. **Latency is accessibility.** A caption 3 seconds late has left the
   conversation.

---

## 2. User journeys

### 2.1 First run
Splash → sign up (no email verification required) → onboarding (5 screens,
forward and back) → Home. Microphone permission is requested **when first
needed**, not at launch, and the prompt is preceded by why it's needed.

### 2.2 Everyday conversation
1. Home → Everyday → **Start conversation**.
2. Tap the mic when the other person begins.
3. Their speech appears as live captions; a natural pause commits that utterance
   as a caption **and keeps listening**.
4. Reply by typing (Send), by having the app speak it (Speak), or with a quick
   reply.
5. Tap the mic to end the speaker's turn; **Stop** ends the conversation.
6. The conversation is temporary: it is discarded when it ends or the screen is
   left.

Expected rhythm: `Speech 1 → Caption 1 → Speech 2 → Caption 2 → …` without
re-tapping between sentences.

### 2.3 Professional session
Create a session (meeting/lecture/class, speech language, folder, retention) →
record → interim text stays hidden, only finalised captions enter the
transcript → stop → save → Summary/Actions generated from the **complete**
transcript → export or share.

Sessions are kept on the phone and deleted when their retention ends (1, 7 or
15 days); the countdown is always visible.

### 2.4 Environmental alerts
Enable monitoring, from the Alerts screen or the Android Quick Settings tile.
Detected sounds raise a notification and vibration, plus a banner, screen flash
and optional torch while the app is open. History is reviewable. Audio is
classified on the phone and never uploaded.

### 2.5 Wellbeing
Home → Wellbeing. The first visit explains the feature and offers an evening
reminder (optional). A check-in is a face, optional words and an optional note;
"Skip" is always there. A low check-in offers ideas; the lowest mood or words
about self-harm open the fixed help screen. Check-ins stay on the phone and can
be deleted one by one or all at once. Never present anything here as a
diagnosis, and never generate text for the help screen.

---

## 3. Copy rules

- Say what happened **and** what to do: "Urdu voice isn't installed on this
  device. Install it in Android settings, then try again."
- Never surface internal identifiers. `Auto`, `sherpaBatch`, `STTMode.none` are
  not user-facing words.
- Both languages, always. A string added in English is not done.
- Never claim AI output is authoritative — the AI disclaimer travels with it.

---

## 4. UX DOs and DON'Ts

**DO**
- Keep the microphone under one obvious control with an unmistakable active state.
- Preserve transcripts across tab switches, rotation and backgrounding.
- Show a distinct *loading*, *empty*, *error* state for every async surface.
- Disable controls that cannot work, and explain why nearby.
- Keep hit targets ≥40dp; the primary mic is 78dp.
- Respect the OS text scale and multiply the in-app setting on top of it.

**DON'T**
- Don't start listening, speaking, or recording without an explicit user action.
- Don't block the UI while the network is slow — always offer stop/cancel.
- Don't let a live session be killed by navigating to another tab.
- Don't show a spinner with no timeout and no cancel.
- Don't hide a failure behind an empty state.

---

## 5. Engineering rules

### 5.1 Speech and transcripts
- **A component uses only the data passed to it.** Never read another service's
  global state for a value you were already given.
- **Model domain events by name.** "Utterance ended" and "session ended" are
  different events with different handlers: a pause never closes the microphone.
- **Finalised text accumulates within a turn.** Never overwrite committed
  recognition output.
- **No empty `onDone`/`onError`.** Every stream terminus either recovers or
  surfaces a failure state. A recognizer that stops producing captions hands
  over to the next one.
- **Set re-entrancy guards synchronously, before the first `await`.** Long async
  start-up carries a generation token and aborts if superseded.

### 5.2 Capabilities, models and caches
- **Diagnostics are silent and invisible.** Capability probes never produce
  sound or anything else the user can perceive.
- **Negative caches expire and are rechecked.** A language pack installed later
  must be discovered.
- **Verify downloads.** "Ready" means *successfully loaded*, not *present*. A file
  that does not match its expected size is discarded and fetched again; no
  failure may be permanent.
- **Load a model the way its library requires, in every isolate that uses it**
  (sherpa-onnx bindings are initialised per isolate). Match classifier labels
  exactly, never by substring.

### 5.3 Errors and state
- **Every async operation exposes idle/loading/success/failure(reason).** An early
  `return` that changes no state is forbidden.
- **If an API can throw, its call sites handle it.** A user-triggered action always
  ends in a visible outcome.
- **Async completions check liveness** before touching state or notifying
  listeners.
- **Announce an alert once, where it is detected.**

### 5.4 Code and platform
- **One implementation per role.** Tests import what the app wires. Delete dead
  code — a duplicate is worse than absent.
- **No direct pushes to `main`.** Never reference a resource in the same change
  that omits it.
- **Every platform service resolved at runtime is declared** (for example the
  `<queries>` entry for `android.speech.RecognitionService`). Treat manifest
  configuration as reviewed code.
- **Know whether an asset is composited or a layer.** Adaptive-icon foregrounds
  carry safe-zone padding and no background.
- **Every release is signed with the one release key** (see
  [releasing.md](releasing.md)).

### 5.5 General DOs
- Write the regression test **and prove it fails without the fix.**
- Test behaviour, not the text of the source.
- Keep changes minimal and reviewable; no drive-by reformatting in a fix commit.
- State uncertainty explicitly.
- Prefer pure functions for anything decision-shaped (recognizer order, turn
  policy, language routing, normalisation) so it is testable without a device.
- Cache with a key that includes everything that invalidates it.

### 5.6 General DON'Ts
- Don't `catch (_) {}`.
- Don't return `null` to signal failure.
- Don't let a test construct a class the app never builds.
- Don't declare "release ready" on unit tests alone — that claim requires a
  device install.
- Don't add a feature that fails closed and silent when its model or network is
  unavailable.

---

## 6. Definition of done

A change is done when:
- the behaviour works on a **physical device** in both languages;
- loading, empty and error states exist;
- failures are visible, with a remedy;
- a regression test exists and was proven to fail beforehand;
- `flutter analyze` adds no new issues and `flutter test` passes;
- the Android build passes in CI;
- both English and Urdu strings are present.
