# Environmental Alerts audit

Focused audit of the existing Environmental Alerts implementation. This file documents the verified scope of the sprint and is intentionally lightweight.

- Preserve the Android foreground-service architecture.
- Keep microphone failures actionable and explicit.
- Use the in-app detector on iOS where the Android bridge is unavailable.
- Persist alert metadata locally (no raw microphone audio).
- Keep alert history bounded and writes ordered.
- Keep critical/non-critical confidence and cooldown behavior unchanged unless tests identify a regression.
