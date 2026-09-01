# HumSukhan Feature-First Architecture

## Goal

Make each product capability independently maintainable, testable, and polishable before the final integration/release.

## Target structure

```text
lib/
  modules/
    auth/
      auth.dart
      screens/
      widgets/
      providers/
      services/
      models/
    onboarding/
      onboarding.dart
      screens/
      widgets/
    splash/
      splash.dart
      widgets/
    home/
      home.dart
      screens/
      widgets/
    conversation/
      conversation.dart
      screens/
      widgets/
      providers/
      services/
      models/
    professional/
      professional.dart
      screens/
      widgets/
      providers/
      services/
      models/
    environmental_alerts/
      environmental_alerts.dart
      screens/
      widgets/
      providers/
      services/
      models/
    settings/
      settings.dart
      screens/
      widgets/
      providers/
    branding/
      branding.dart
      widgets/
      assets/
    core/
      core.dart
```

## Ownership

### Conversation

Owns Everyday/Conversational Mode, speaker microphone lifecycle, live captions, caption history, TTS actions, speech state presentation, and conversation-specific tests.

### Professional

Owns Professional Mode, live professional sessions, session details/history, insights presentation, and professional-specific tests.

### Environmental Alerts

Owns environmental monitoring UI, microphone/service lifecycle, sound classification presentation, alert history, and environmental-specific tests.

### Settings

Owns preferences and settings UI, accessibility controls, theme/language choices, alert preferences, and settings-specific tests.

### Auth

Owns sign-in/sign-up UI, authentication presentation, auth state adapters, and authentication-specific tests.

### Onboarding

Owns first-run setup, permissions guidance, and onboarding-specific tests.

### Splash

Owns startup/splash presentation and startup-specific tests.

### Home

Owns dashboard/home presentation and feature entry points. It should not own the internals of another feature.

### Branding

Owns logo/brand presentation and reusable brand widgets. Raw Flutter assets remain under `assets/` until extraction is useful.

### Core

Owns only cross-cutting infrastructure: navigation, localization, theme primitives, reusable shared widgets/models, platform adapters, and app-wide utilities.

## Migration sequence

1. Establish stable module boundaries and barrels without behavior changes.
2. Migrate one feature at a time into its module.
3. Move feature-specific providers/services/models beside the feature when they are not shared.
4. Add focused tests for each module.
5. Remove the corresponding legacy `screens/`, feature-specific provider/service files once imports are migrated.
6. Integrate modules through the app shell/router.
7. Run complete QA and release only from the integrated `main`.

## Rule

A module may depend on `core` and its own internals. Cross-feature dependencies should be minimized and should normally pass through a clearly defined public module API rather than reaching into another module's private implementation.
