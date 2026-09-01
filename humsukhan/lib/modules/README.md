# HumSukhan Feature Modules

HumSukhan is being organized by product capability rather than only by technical file type.

Each feature module owns its screen(s), feature-specific widgets, state, and adapters where practical. Shared infrastructure stays in the common `models/`, `services/`, `theme/`, `navigation/`, `l10n/`, and `widgets/` areas until it is safely extracted into a reusable module.

## Modules

- `conversation/` — Everyday / Conversational Mode, live captions, speaker controls, TTS integration.
- `professional/` — Classes, meetings, lectures, live professional sessions, session detail/history.
- `environmental_alerts/` — Environmental Alerts UI, microphone monitoring lifecycle, sound events.
- `settings/` — User preferences, language, accessibility, theme, notification and alert settings.
- `auth/` — Sign in, sign up, session/account gate.
- `onboarding/` — First-run onboarding and permissions guidance.
- `splash/` — Startup/splash experience.
- `home/` — Home/dashboard and feature entry points.
- `branding/` — Logo and brand assets/widgets.

## Migration rule

The first architecture commit creates stable module boundaries without changing runtime behavior. Existing implementation files remain temporarily in the legacy directories while module entry points are introduced. Each module can then be migrated internally and tested independently.

Do not duplicate business logic between a module and `screens/`/`services/`. During each migration, choose one source of truth and remove the old path once imports are updated and CI is green.
