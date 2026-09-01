# Changelog

## 2.3.0 — 2026-09-02

### Production readiness

- Hardened Android release signing so production builds no longer use the debug signing key.
- Added CI release signing through protected GitHub Actions secrets.
- Changed Android release automation to publish only from versioned `vX.Y.Z` tags.
- Added a release-time check that the Git tag matches the Flutter app version.

### Reliability and privacy

- Isolated locally cached profile, Conversation history, Professional records, and Quick Replies per signed-in account.
- Preserved existing cloud synchronization and offline behavior.
- Stabilized startup, authentication, onboarding, Home, Conversation Mode, Professional Mode, Environmental Alerts, and Settings flows through the completed audit cycle.

### Accessibility

- Preserved English/Urdu localization, large-text handling, reduced-motion behavior, speech captions, TTS fallback behavior, and environmental alert accessibility paths.

### Release validation

- Flutter QA workflow remains the required static-analysis and test gate.
- Physical-device validation remains required for Android background environmental monitoring, notification-denied behavior, iOS background audio lifecycle, and real-device STT/TTS interruption behavior.
