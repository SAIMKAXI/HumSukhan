# HumSukhan — Experience Guide, DOs and DON'Ts

Two audiences in one document:

- **§1–4** the intended user experience, end to end.
- **§5** engineering rules. §5.1 is a register of bugs that **actually shipped**.
  Each one is written as a rule with its root cause, so it cannot be
  reintroduced by someone who wasn't there.

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
skippable forward/back) → Home. Microphone permission is requested **when first
needed**, not at launch, and the prompt is preceded by why it's needed.

### 2.2 Everyday conversation
1. Home → Everyday → **Start conversation**.
2. Tap the mic when the other person begins.
3. Their speech appears as live captions; a natural pause commits that utterance
   as a caption **and keeps listening**.
4. Reply by typing (Send) or by having the app speak it (Speak), or tap a quick
   reply.
5. Tap the mic to end the speaker's turn; **Stop** ends the conversation.
6. Choose Save / Delete / Continue.

Expected rhythm: `Speech 1 → Caption 1 → Speech 2 → Caption 2 → …` without
re-tapping between sentences.

### 2.3 Professional session
Create session (meeting/lecture/class, language, retention) → record → interim
text stays hidden, only finalised captions enter the transcript → stop → save →
Summary/Actions generated from the **complete** transcript → export/share.

Sessions auto-expire per retention (max 15 days) with the countdown visible.

### 2.4 Environmental alerts
Enable monitoring (needs mic + the on-device sound model) → detected events
raise haptic + visual + optional torch/screen flash → history is reviewable.
Audio is classified on-device and never uploaded.

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

### 5.1 Bug register — these shipped; do not reintroduce them

Each entry: what the user saw → why → the rule.

**B1 · Captions repeated the first phrase forever**
`ConversationProvider.commitSpeakerTurn()` overwrote the draft with
`DeepgramTranscriptionService.instance.lastFinalTranscript` — a singleton owned
by a *different* recognizer that Everyday Mode never starts, and cleared only
inside that service's own `start()`. It held one stale utterance and replaced
every subsequent caption.
> **RULE:** a component may only use data passed to it. Never reach into another
> service's global state for a value you were already given.

**B2 · Recognition stopped after the first utterance**
The silence timer was armed directly on `_stopListening()`, which closes the
microphone. A pause was never meant to end the session.
> **RULE:** model domain events by name. "Utterance ended" and "session ended"
> are different events with different handlers.

**B3 · Speaking again quickly dropped the previous sentence**
Turn text was *replaced* on every result, while the recognizer clears its buffer
after each final — so utterance 1 vanished when utterance 2 started.
> **RULE:** finalised text accumulates within a turn. Never overwrite committed
> recognition output. Losing transcript is the highest-severity class of bug.

**B4 · Professional Mode stopped capturing mid-session**
Both recognizer sockets used `onDone: () {}`. A dropped connection left the mic
streaming into a dead socket while the UI still read "Listening…".
> **RULE:** never write an empty `onDone`/`onError`. Every stream terminus either
> recovers or surfaces a failure state.

**B5 · The app spoke to itself after sign-in**
The TTS capability probe performed real synthesis (`speak('.')`, up to three
locales) and ran on **every app resume** where a language was a cached negative —
the normal state for Urdu.
> **RULE:** diagnostics are silent and invisible. Mute before probing; never let
> instrumentation produce user-perceivable output.

**B6 · Environmental monitoring could never start again**
`_downloadFile` only checked the file was non-empty, so a truncated download was
installed as complete. `initialize()` then only checked the files *existed*, so
the corrupt model reported ready, `downloadModel()` short-circuited, the tagger
failed — permanently.
> **RULE:** verify downloads against `Content-Length`/checksum. "Ready" means
> *successfully loaded*, not *present*. Any unusable cached artefact is
> quarantined and refetched — no failure may be permanent.

**B7 · AI Summary appeared broken**
`generateInsights()` returned early on five distinct failures with no state
change; the provider had no in-flight flag and no error field, so failure,
in-progress and never-requested all rendered identically.
> **RULE:** every async operation exposes idle/loading/success/failure(reason).
> An early `return` that changes no state is forbidden.

**B8 · Speak failures were invisible**
`speak()` rethrows when native *and* cloud TTS both fail; no call site caught it,
so the exception reached the zone handler and the user saw nothing happen.
> **RULE:** if an API can throw, its call sites handle it. A user-triggered
> action always ends in a visible outcome.

**B9 · A device could never rediscover an installed language**
The capability cache only rechecked negatives when the *overall* recognizer flag
was false, so installing an Urdu pack later was never noticed.
> **RULE:** negative caches expire and are rechecked. Never let a false negative
> permanently disable working hardware.

**B10 · Two rapid taps opened two microphone sessions**
Re-entrancy guards were set after an `await`, leaving a window where both calls
passed the check; and `stop()` during an in-flight `start()` couldn't cancel it.
> **RULE:** set the guard synchronously before the first `await`. Long async
> start-up carries a generation token and aborts if superseded.

**B11 · Two `SpeechProvider` classes; tests validated the dead one**
A duplicate implementation existed and two regression tests imported it rather
than the class the app builds.
> **RULE:** one implementation per role. Tests import what the app wires. Delete
> dead code — a duplicate is worse than absent.

**B12 · The release build broke on `main`**
`<monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>` was pushed
without the asset, straight to `main`, bypassing CI. Every build failed at
resource linking.
> **RULE:** no direct pushes to `main`. Never reference a resource in the same
> change that omits it.

**B13 · The in-app logo lost its brand green**
`BrandLogo` was pointed at the transparent adaptive-icon *foreground* while its
container filled with `colorScheme.surface`.
> **RULE:** know whether an asset is composited or a layer. Adaptive-icon
> foregrounds carry safe-zone padding and no background.

**B14 · The device recognizer was invisible to the app**
Android 11+ package visibility requires a `<queries>` entry for
`android.speech.RecognitionService`; only the TTS queries were declared.
> **RULE:** every platform service the app resolves at runtime is declared. Treat
> manifest configuration as reviewed code.

**B15 · `notifyListeners()` after dispose**
A provider's async constructor load notified unconditionally.
> **RULE:** async completions check liveness before touching state.

### 5.2 General DOs

- Write the regression test **and prove it fails without the fix.**
- Keep changes minimal and reviewable; no drive-by reformatting in a fix commit.
- State uncertainty explicitly. "I could not reproduce this from a device log" is
  a valid, valuable thing to write in a PR.
- Prefer pure functions for anything decision-shaped (turn policy, language
  routing, normalization) so it is testable without a device.
- Cache with a key that includes everything that invalidates it.

### 5.3 General DON'Ts

- Don't `catch (_) {}`.
- Don't return `null` to signal failure.
- Don't put stateful services in singletons.
- Don't let a test construct a class the app never builds.
- Don't declare "release ready" on unit tests alone — that claim requires a
  device install.
- Don't add a feature that fails closed and silent when its model/network is
  unavailable.

---

## 6. Definition of done

A change is done when: the behaviour works on a **physical device** in both
languages; loading/empty/error states exist; failures are visible with a remedy;
a regression test exists and was proven to fail beforehand; `flutter analyze`
adds no new issues; `flutter test` passes; the Android build passes in CI; and
both English and Urdu strings are present.
