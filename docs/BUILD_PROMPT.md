# Build Prompt — HumSukhan v1.0.0 from scratch

A single self-contained brief for an engineering agent. It is deliberately
specific about failure modes: every constraint in §7 exists because that exact
bug shipped in the previous build.

Copy everything from **BEGIN PROMPT** to **END PROMPT**.

---

## BEGIN PROMPT

You are the senior Flutter engineer building **HumSukhan** to a releasable
v1.0.0. Work in small, verified increments: implement → analyze → test → fix →
only then move on. Never stack unverified changes.

### 1. Product

An accessibility-first Android/iOS app for Deaf and hard-of-hearing users,
English + Urdu, three pillars:

1. **Everyday** — live captions of the person speaking to the user, plus
   text-to-speech replies.
2. **Professional** — long-form meeting/lecture capture producing a complete
   transcript, then an AI summary with action items.
3. **Environmental** — on-device detection of safety-relevant sounds (siren,
   doorbell, alarm, baby cry, knock, glass break, dog bark, vehicle horn, phone)
   with haptic/visual alerts.

Design for a user who **cannot hear failures**. Any state communicated only by
sound does not exist.

### 2. Stack

Flutter (stable) · Dart 3 · Riverpod · Supabase (auth, Postgres+RLS, Edge
Functions) · Deepgram streaming STT via **ephemeral tokens minted server-side** ·
platform TTS with a cloud fallback · sherpa-onnx CED-Tiny INT8 for on-device
audio tagging.

**No third-party API key may ever reach the client.** All provider credentials
live in Edge Functions; the client receives short-lived tokens only.

### 3. Architecture (required)

Strict inward-pointing layers, enforced by lint:

```
core/  domain/  application/  infrastructure/  features/
```

- `domain` imports no Flutter and no plugin. It holds entities and **ports**.
- Speech is behind narrow ports:
  - `SttPort` — `Stream<SttEvent>` where `SttEvent = Partial | Final | Ended(reason) | Failed(cause)`
  - `TtsPort`, `SpeechCapabilityPort`
  - The `Ended`/`Failed` variants are mandatory: a session must be able to say it stopped.
- Exactly **one** owner of live speech state: a `ConversationSession` state
  machine with states `idle · starting · listening · speaking · reconnecting ·
  failed`. `reconnecting` and `failed` are rendered by the UI, not internal flags.
- Turn segmentation is a **pure function** `decide(TurnState, TurnSignal) →
  TurnDecision` so it is unit-testable with no plugins.
- All fallible operations return `Result<T, Failure>`. Failures carry
  `message`, optional `remedy`, and `isRecoverable`.
- No stateful singletons; lifetimes owned by the DI container.

### 4. Features to ship in v1.0.0

**Auth** — email/password sign up, sign in, sign out, password reset, session
restore. **No mandatory email verification.** Per-user data scoping; switching
user rebuilds all state.

**Everyday** — start/stop conversation; mic toggle; live partial captions;
a configurable pause threshold (1.2s / 1.7s / 2.5s / manual) that **commits the
current utterance and keeps listening**; typed replies; TTS replies; quick
replies; save/delete on stop.

**Professional** — sessions with type, caption language and retention (max 15
days, countdown shown); interim text stays hidden, only finals enter the
transcript; long sessions (30+ min) must survive transport drops via reconnect;
AI summary + action items + deadlines + mentioned people from the **complete**
transcript; export/share.

**Environmental** — mic → 16kHz mono PCM16 → RMS gate → 3s window / 1s hop →
local CED-Tiny INT8 → confidence + temporal confirmation → severity → alert.
Android foreground service (`foregroundServiceType="microphone"`) + Quick
Settings tile. **Ship the model in the app bundle**; a runtime download may only
be an updater. No audio leaves the device.

**Settings** — dark mode, high contrast (a dedicated `ThemeData`, not a filter),
large text (multiplies the OS text scale by 1.2), caption size, app + caption
language, alert channels (haptic/visual/torch/screen flash), retention, account.

### 5. Design

Brand green `#53695B`; sage/forest palette; `NotoSans` for Latin and
`NotoNastaliqUrdu` for Urdu with `height: 1.65` applied to every Urdu text style
(Nastaliq clips otherwise). Radii 12/16/20/full; spacing 4/8/16/24/32/48.
5-tab `NavigationBar` (Home · Everyday · Professional · Alerts · Settings) over
an `IndexedStack` so live sessions survive tab switches.

Mixed-script captions render **per run** — direction is decided per text run, not
per screen. Hit targets ≥40dp; primary mic 78dp.

Adaptive launcher icon with **all three** layers (background, transparent
foreground, monochrome). The in-app brand badge uses the mark-only asset on
brand green, scaled 108/72 to match the launcher framing.

### 6. Language contract

English and Urdu only. Roman Urdu normalises to Urdu script. **Devanagari is
stripped before any routing or display and is never treated as Urdu.** Never
substitute Hindi for Urdu at any layer. Language classification is displayed to
the user, never silently corrected, and internal mode names (`Auto`, `none`)
never appear in UI copy.

### 7. Hard constraints — each prevents a bug that actually shipped

1. **No ambient global reads.** A component uses only data passed to it. (A
   caption committer once overwrote text with a stale singleton owned by a
   different, unused recognizer — every caption repeated the first phrase.)
2. **A pause ends an utterance, not the session.** Distinct domain events,
   distinct handlers.
3. **Finalised text accumulates within a turn; never overwrite it.** Dropping
   recognised speech is the highest-severity bug class.
4. **No empty `onDone`/`onError`.** Every stream terminus recovers or surfaces a
   failure. A live session must be able to report that it died.
5. **Diagnostics are silent and invisible.** Mute before any capability probe.
   Never let instrumentation emit audio.
6. **"Ready" means successfully loaded, not "the file exists."** Verify downloads
   against `Content-Length`/checksum; quarantine and refetch anything unusable.
   No failure may be permanent.
7. **Every async operation exposes idle/loading/success/failure(reason).** An
   early `return` that changes no state is forbidden.
8. **Every user-triggered action ends in a visible outcome.** If an API throws,
   its call sites handle it.
9. **Negative capability caches expire and are rechecked** (per language), keyed
   on platform + OS version + engine id + language.
10. **Re-entrancy guards are set synchronously before the first `await`**;
    long async start-up carries a generation token and aborts if superseded.
11. **One implementation per role.** Tests import the class the app actually
    wires. Delete dead code.
12. **Never reference a platform resource in a change that omits it.** Declare
    `<queries>` for **both** `TTS_SERVICE` and `android.speech.RecognitionService`
    (Android 11+ package visibility), plus `RECORD_AUDIO`,
    `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`.
13. **No `catch (_) {}`. No `null` as a failure signal. No stateful singletons.**
14. **Async completions check liveness before touching state.**

### 8. Testing

- Pure unit tests for turn policy, language classification, normalizers.
- Application tests against **fake ports** — the whole speech stack must be
  testable with no device and no network.
- Widget tests with overridden providers for every loading/empty/error state.
- `integration_test` for the three end-to-end journeys.
- **Every regression test must be demonstrated to fail on the unfixed code.** If
  it cannot reproduce the original condition, say so in the test rather than
  claiming coverage you don't have.

### 9. Delivery

- `main` protected; no direct pushes; all work via PR.
- CI on every PR: `dart format --set-exit-if-changed`, `flutter analyze
  --fatal-infos`, `flutter test --coverage`, `flutter build apk --debug`.
- Release workflow is tag-driven, asserts tag == pubspec version, asserts the APK
  exists and is non-empty before publishing, and attaches it to a GitHub Release.
- Keep a CHANGELOG written for users, not commit subjects.

### 10. Definition of done for v1.0.0

Dependencies resolve · analyzer clean · all tests pass · Android debug **and**
release builds pass in CI · signed APK attached to the release · version matches
tag · both languages complete · every async surface has loading/empty/error
states · **and the three journeys have been exercised on a physical device.**

Do not report "release ready" on the strength of unit tests alone. State plainly
what has been verified by automation and what still needs a device.

## END PROMPT

---

## Notes for whoever runs this

- §7 is the highest-value section. If the agent internalises nothing else, those
  fourteen constraints prevent the defects that cost the most rework.
- Require the "prove the test fails first" discipline from day one; it is the
  only reliable defence against tests that validate code the app doesn't run.
- Budget for physical-device testing explicitly. CI cannot tell you that an
  adaptive icon looks wrong under a Samsung mask, that a TTS probe is audible, or
  that a recognizer dies after ninety seconds.
