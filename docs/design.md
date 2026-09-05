# HumSukhan — UI & Design Specification (as-built)

**Scope:** documents the interface that ships in v2.4.x. This is a description of
what exists, not an aspiration. Where the current UI has known debt it is called
out under *Design debt* rather than quietly idealised.

**Audience:** designers and engineers changing the interface, and anyone
rebuilding it.

---

## 1. Product framing

HumSukhan ("هم سخن" — *one who speaks with you*) is an accessibility-first
communication assistant for Deaf and hard-of-hearing users, built around three
pillars. Every design decision serves one of them:

| Pillar | Screen | Job to be done |
|---|---|---|
| **Everyday** | Conversational Mode | See what the person in front of me is saying, and reply out loud |
| **Professional** | Sessions | Capture a lecture/meeting completely, then understand it |
| **Environmental** | Alerts | Know about sounds I cannot hear (doorbell, siren, alarm) |

Two cross-cutting constraints shape everything:

1. **Bilingual, mixed-script.** English and Urdu appear *in the same sentence*.
   Layout, fonts and direction must survive that, not just switch wholesale.
2. **The user may not be able to hear failures.** An error that is only audible,
   or a control that silently does nothing, is a total failure for this audience.

---

## 2. Brand

### 2.1 Mark

A quill/feather inside a speech bubble with a three-dot ellipsis — "writing" and
"speaking" combined. Cream shape on brand green.

| Asset | Purpose |
|---|---|
| `assets/logo.png` | Full lockup (mark + Urdu wordmark), transparent — large contexts only |
| `assets/icon_mark.png` | Mark only, transparent, safe-zone padded — small badges |
| `assets/logo_rectangle*.png` | Wide lockups, for share cards/readme |
| `mipmap-anydpi-v26/ic_launcher_{background,foreground,monochrome}.png` | Android adaptive icon layers |

**Rule:** the wordmark is illegible below ~120dp. Anything smaller uses
`icon_mark.png`. The in-app badge (`BrandLogo`) scales the mark by `108/72` to
reproduce the launcher icon's framing, because that asset carries adaptive-icon
safe-zone padding.

### 2.2 Colour

Brand green, sage-derived. `AppTokens` (`lib/theme/app_theme.dart`):

| Token | Hex | Use |
|---|---|---|
| `brandIconBackground` | `#53695B` | Launcher icon bg + in-app brand badge (must match exactly) |
| `deepSage` | `#506858` | Primary, success |
| `primarySage` | `#587060` | Primary variant, info |
| `mediumSage` / `lightSage` / `softSage` | `#607868` / `#688070` / `#789080` | Secondary surfaces, muted text |
| `darkForest` / `deepForest` / `forestBlack` | `#3A4F42` / `#2D3E34` / `#1E2B22` | Dark-mode surfaces, primary text |
| `warmIvory` / `creamWhite` / `softCream` | `#F8F0E8` / `#F0E8E0` / `#F0F0E0` | Light surfaces |
| `borderSage` / `mutedSageGray` / `disabledSage` | `#D0D8D4` / `#B8C4BC` / `#C8D0CC` | Dividers, disabled |
| `warning` | `#B8943C` | Non-critical alerts |
| `error` | `#B85450` | Errors, critical alerts, active-recording state |

Three themes are built from these: **light**, **dark**, and a separate
**high-contrast** theme constructed in `main.dart` (pure black/white with
1.5–2.5px borders on every control). High contrast is *not* a filter over the
normal theme — it is its own `ThemeData`, because a derived one could not
guarantee contrast ratios.

### 2.3 Typography

| Script | Family | Notes |
|---|---|---|
| Latin | `NotoSans` | Default |
| Urdu / Arabic | `NotoNastaliqUrdu` | Nastaliq needs vertical room |

Urdu applies `height: 1.65` to **every** text style (`_withUrduMetrics` in
`main.dart`). Nastaliq descenders clip at normal line height — this is not
optional polish.

Scale (`AppTokens`): `captionSmall 12 · caption 13 · body 15 · bodyLarge 17 ·
title 20 · headline 28 · display 32`.

### 2.4 Shape & spacing

Spacing: `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`.
Radius: `radiusSm 12 · radiusMd 16 · radiusLg 20 · radiusFull 999`.

---

## 3. Navigation

`MainScaffold` — a 5-destination `NavigationBar` over an `IndexedStack`
(state is preserved across tab switches; a live session is never torn down by
navigating away).

`Home · Everyday · Professional · Alerts · Settings`

Gate order at startup (`_AccountGate`): password-recovery → settings loaded →
authenticated → onboarding complete → `MainScaffold`.

---

## 4. Component inventory

`lib/widgets/` — all reusable, all theme-driven.

| Component | Role | States it must express |
|---|---|---|
| `BrandLogo` | Brand badge on green | — |
| `SpeakableCaptionBubble` | A caption + its Speak button | own/other, partial/final, speaking/idle, empty-disabled |
| `MixedScriptCaptionText` | Direction-aware mixed-script rendering | RTL run, LTR run |
| `CaptionBubble` | Static caption | partial (italic), final (medium) |
| `StatusIndicator` / `StatusPill` | Live mic/connection state | active, inactive |
| `LanguageBadge` | Detected caption language | English / Urdu / Roman Urdu / Auto |
| `OfflineBadge` | Connectivity | online, offline |
| `QuickReplyChip` | One-tap phrase | enabled, disabled (while listening) |
| `SessionCard` | Session in a list | in-progress, completed, expiring |
| `RetentionBadge` | Days until auto-delete | normal, near-expiry |
| `InsightCard` | AI summary block | — |
| `AlertCard` | Detected sound event | severity, dismissed |
| `EmptyState` / `ErrorState` | Zero and failure states | title + message + action |
| `AiDisclaimer` | "AI may be wrong" notice | — |
| `PrivacyNotice` / `PrivacyStrip` | On-device/retention messaging | — |
| `PrimaryActionButton` / `SecondaryActionButton` | Actions | enabled, disabled, loading |
| `ModernModeCard` / `ModernSectionHeader` | Home dashboard | — |

---

## 5. Screens

### 5.1 Splash
Brand mark, single-fire completion callback, semantics exposed for screen
readers. Hands off to `_AccountGate`.

### 5.2 Auth
Sign in · sign up · forgot password · password recovery in one screen driven by
a mode enum. Feedback via `SnackBar`. **No mandatory email verification** —
deliberate product decision. Errors are specific ("enter a valid email", not
"error").

### 5.3 Onboarding
5 pages: Welcome (logo hero) → Everyday → Professional → Environmental →
Privacy. Next/Back/Get started. Completion persists to settings.

### 5.4 Home
Greeting (profile name → auth metadata → app name fallback), connectivity pill,
mode cards to the three pillars, recent activity.

### 5.5 Everyday (Conversational Mode)
The most complex screen. Three states via `ConversationState`:

- **idle** — privacy notice + "Start conversation"
- **active** — speaker controls, caption list, quick replies, composer, Stop
- **saveDecision** — Save / Delete / Continue

**Speaker controls:** 78dp circular mic (primary → error red while listening,
spinner while busy), status label, and a pause-threshold menu
(*Short 1.2s · Natural 1.7s · Patient 2.5s · Manual only*).

**Caption area:** `ListView.builder` of `SpeakableCaptionBubble`, keyed by
caption id, with the live partial appended as the last item. Own captions right
aligned, speaker captions left.

**Composer:** multiline field (1–4 lines, max 120dp), auto-switches to RTL +
Nastaliq when Urdu is typed, Speak button, Send button. Both disabled while the
speaker's mic is live or the engine is busy.

**Turn model:** a pause ends an *utterance* (commit this caption, keep
listening); the mic button ends the *session*. The status line says "Pause
detected — speak again to continue" precisely because the mic stays open.

### 5.6 Professional — list & live session
List of sessions with type (meeting/lecture/class), retention badge, folders.

Live session: hidden interim drafts (Professional must **never** flicker
half-recognised text into the transcript — only finalised captions are
committed), manual caption entry, Speak reply, duration timer, stop → save /
discard / continue.

### 5.7 Session detail
Tabs: Overview · Summary · Actions · Transcript. Summary shows three distinct
states — **generating** (spinner), **failed** (reason), **empty** — never one
ambiguous blank. Export/share. AI disclaimer always visible with AI output.

### 5.8 Environmental
Monitoring toggle, live state banner (off / starting / active / error with a
specific reason and remedy), supported-event list, alert history, per-event
alert preferences.

### 5.9 Settings
Profile (name, avatar) · appearance (dark, high contrast, large text, caption
size) · language (app + caption) · alert channels (haptic, visual, flash,
screen flash) · retention · offline models · account.

---

## 6. Bilingual & RTL rules

1. App language drives `Directionality` and font family app-wide.
2. Caption text is rendered **per run**, not per screen — a caption containing
   both scripts renders each run in its own direction (`MixedScriptCaptionText`).
3. The composer follows *typed* content, not app language.
4. Language classification is displayed, never silently corrected.
5. Devanagari is stripped before display and never treated as Urdu.

---

## 7. Accessibility

- **Large text** multiplies the platform text scale by 1.2 on top of the user's
  OS setting (`MediaQuery.textScaler`), never replacing it.
- **Caption size** is independently adjustable from app text size.
- **High contrast** is a dedicated theme (§2.2).
- **Alerts are multi-channel** — haptic, visual, torch flash, screen flash —
  because the primary user cannot rely on sound.
- Minimum hit target 40dp (`SpeakableCaptionBubble`'s Speak button sets
  `minWidth/minHeight: 40`); the primary mic is 78dp.
- Semantics labels on the mic ("Start/Stop speaker microphone") and splash.

---

## 8. Feedback & failure presentation

Non-negotiable: **every failure is visible.**

| Failure | Presentation |
|---|---|
| Speak (TTS) fails | `SnackBar` with the reason |
| Mic can't start | Inline error + specific cause |
| Recognizer disconnects | Reconnect attempt, then a stated reason |
| Monitoring can't start | Banner naming the cause *and* the remedy |
| AI summary fails | Distinct failed state with reason |
| Offline | `OfflineBadge` |

---

## 9. Design debt (honest list)

- Onboarding hero uses a hardcoded radius (40) instead of an `AppTokens` value.
- `SpeakableCaptionBubble` decides "is this bubble speaking" by comparing caption
  *text* to `lastSpokenText`; two identical captions both show the stop icon.
- `LanguageBadge` can render the literal string `Auto` for mixed-script captions
  — an internal mode name leaking into UI copy.
- Several dense one-line widget files are hard to review.
- `lib/modules/**` is a half-finished feature-first migration; the barrels alias
  back to `lib/screens/**`. It is scaffolding, not structure.
