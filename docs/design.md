# HumSukhan — UI & Design Specification

**Scope:** the interface as built: brand, design system, components and screens.

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
| **Environmental** | Alerts | Know about sounds I cannot hear (siren, doorbell, knock) |

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
| `assets/logo.webp` | Full lockup (mark + Urdu wordmark), transparent — large contexts only |
| `assets/icon_mark.webp` | Mark only, transparent, safe-zone padded — small badges |
| `mipmap-anydpi-v26/ic_launcher_{background,foreground,monochrome}.png` | Android adaptive icon layers |

**Rule:** the wordmark is illegible below ~120dp. Anything smaller uses
`icon_mark.webp`. The in-app badge (`BrandLogo`) scales the mark by `108/72` to
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
| Latin | `NotoSans` | Fallback: Nastaliq |
| Urdu / Arabic | `NotoNastaliqUrdu` (Regular 400, Bold 700) | Fallback: Noto Sans |

One pair of typefaces everywhere: each script always renders in its own face,
whichever language the app is in, so nothing falls back to a system font.
`AppTypography` (`lib/theme/app_typography.dart`) owns this, and
`AppTheme.forApp` applies it to every text style the theme hands out (text
themes, app bar, navigation bar, buttons, chips, snack bars).

Urdu metrics, applied to every style in Urdu and to any Urdu run in English:

- **Line height 2.0** with even leading. Nastaliq rises and falls far beyond
  Latin, so lines collide or clip at Latin heights.
- **Word spacing 0.25 × font size.** The font's own word space is so narrow
  that neighbouring words read as one ("اورپیشہ").

Rules:

- A style that sets its own line height uses
  `AppTypography.latinLineHeight(context, h)`, which yields to the Urdu line
  height in Urdu.
- Text whose script is known only at run time (captions, notes, the composer)
  uses `AppTypography.forText` or `urduStyle`.
- Clock times go through `AppStrings.clockTime`: Urdu names the part of the
  day (صبح، دوپہر، شام، رات) because the Urdu locale data has only Latin AM/PM.

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
| `StatusIndicator` / `StatusPill` | Live mic/connection state | active, inactive |
| `LanguageBadge` | Detected caption language | English / Urdu / mixed |
| `OfflineBadge` | Connectivity | online, offline |
| `QuickReplyChip` | One-tap phrase; long-press to star or delete | enabled, disabled (while listening), starred |
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
- **ended** — "Conversation ended": Done / Continue listening. The conversation
  is temporary and is not saved.

**Speaker controls:** 78dp circular mic (primary → error red while listening,
spinner while busy), status label, and a pause-threshold menu
(*Short 1.2s · Natural 1.7s · Patient 2.5s · Manual only*).

**Caption area:** `ListView.builder` of `SpeakableCaptionBubble`, keyed by
caption id, with the live partial appended as the last item. Own captions right
aligned, speaker captions left.

**Quick replies:** a scrolling row of every reply, starred ones first, then the
user's own (newest first), then the built-in ones. Managed in Settings.

**Composer:** multiline field (1–4 lines, max 120dp), auto-switches to RTL +
Nastaliq when Urdu is typed, Speak button, Send button. Both disabled while the
speaker's mic is live or the engine is busy.

**Turn model:** a pause ends an *utterance* (commit this caption, keep
listening); the mic button ends the *session*. The status line says "Pause
detected — speak again to continue" precisely because the mic stays open.

### 5.6 Professional — list & live session
Tabs: Folders · Classes · Meetings · Lectures. Folders lists General and the
user's folders, with Create Folder; a folder can be deleted on its own (its
sessions move to General) or together with its sessions. Sessions show type,
retention badge and insight state.

New session sheet: title, type (meeting/lecture/class), speech language
(Auto · English · Urdu), folder, retention (1 · 7 · 15 days).

Live session: hidden interim drafts (Professional must **never** flicker
half-recognised text into the transcript — only finalised captions are
committed), manual caption entry, Speak reply, duration timer. Stop offers
Save session · Discard · Continue; a saved session stays on the phone.

### 5.7 Session detail
Tabs: Overview · Transcript · Summary · Actions. Summary shows three distinct
states — **generating** (spinner), **failed** (reason), **empty** — never one
ambiguous blank. The menu offers Export (text file or clipboard), Move to
folder and Delete. AI disclaimer always visible with AI output.

### 5.8 Environmental
Monitoring toggle, live state banner (off / starting / active / error with a
specific reason and remedy), supported-event list, alert history, per-event
alert preferences.

### 5.9 Settings
Profile (name, photo) · account (sign in / sign out) · app language ·
accessibility (dark, high contrast, large text, caption size) · alert channels
(haptic, visual, screen flash, flashlight) · speech recognition (offline model
downloads with progress) · environmental sounds (one switch per sound) · quick
replies · default retention · reset settings · about.

---

## 6. Bilingual & RTL rules

1. App language drives `Directionality` and font family app-wide.
2. Caption text is rendered **per run**, not per screen — a caption containing
   both scripts renders each run in its own direction (`MixedScriptCaptionText`).
3. The composer follows *typed* content, not app language.
4. Language classification is displayed, never silently corrected.
5. Devanagari is stripped before display and never treated as Urdu.
6. Layout uses start and end (`EdgeInsetsDirectional`, `AlignmentDirectional`,
   `TextAlign.start`), so it mirrors in Urdu. Left and right appear only where
   chosen from the script of a piece of text. `test/urdu/rtl_source_test.dart`
   enforces this.
7. Nothing shown in Urdu is English. Messages from providers, services and
   Supabase go through `AppStrings.message`, which translates them or falls
   back to a general Urdu error; the Android notification and tile strings
   follow the app language too (`NativeStrings.kt`). English that is meant to
   be English (the English half of a bilingual card, the language's own name)
   carries `locale: Locale('en')`.
8. `test/urdu/` opens every screen, dialog and sheet in Urdu on a 360×640
   phone at text scale 1.0 and 1.3 and fails on any English or any overflow.
   `urdu_screenshots_test.dart` renders them all for review on request.

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
| Recognizer disconnects or stalls | Next recognizer takes over; a stated reason only if none can start |
| Offline model download fails | `SnackBar` with the reason; Download stays available |
| Monitoring can't start | Banner naming the cause *and* the remedy |
| AI summary fails | Distinct failed state with reason |
| Offline | `OfflineBadge` |
