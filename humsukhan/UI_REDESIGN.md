# HumSukhan UI Redesign

The 2026 redesign keeps the existing sage / forest / ivory brand palette and replaces the previous screen-by-screen styling with one mobile-first visual system.

## Visual direction
- Calm, trustworthy assistive-AI workspace rather than a generic utility app.
- Warm ivory neutral canvas with forest/sage anchors.
- 60/30/10 hierarchy: neutral foundation, dark complementary text/surfaces, restrained sage accent.
- 8-point spacing rhythm with 4/12 companions only where needed for text/control alignment.
- Rounded organic surfaces, soft shadows, subtle accent-tinted depth.
- One primary font family (`NotoSans`) with a deliberately small type scale and two primary weights.
- Minimum 44pt interactive targets.

## Navigation
The primary mobile shell uses a bottom `NavigationBar` so the five core destinations stay in the thumb zone:
Home, Everyday, Professional, Environmental Alerts, and Settings.

## Screen hierarchy
### Home
- Brand/header context first.
- Greeting and identity before actions.
- Three core capabilities presented as large, scannable mode cards.
- Recent work is secondary, with a purposeful empty state.
- Privacy is visible without becoming a blocking banner.

### Authentication
- Brand mark and purpose are visible before the form.
- Sign-in/sign-up is a segmented control rather than two competing links.
- Inputs use large touch-friendly controls and one dominant CTA.
- Errors and privacy information are contextual and readable.

### Splash
- Short, calm motion sequence with the brand mark as the peak visual moment.
- Minimal copy and a restrained progress cue; no decorative clutter.

### Conversation / Professional / Environmental / Settings
Existing functionality is preserved. The new global theme, card system, inputs, navigation treatment, typography and status language provide a consistent baseline; these feature modules can now receive detailed module-level visual polish independently.

## Interaction principles
- Primary action stays in the lower thumb-friendly region when the screen needs one.
- Empty, loading, error, and success states are intentional states, not afterthoughts.
- Motion should confirm state changes, not distract from comprehension.
- Strong red is reserved for meaningful errors/critical alerts.

## Accessibility
- Large touch targets.
- High contrast between text and surfaces.
- Urdu remains supported and layouts use flexible text containers rather than fixed widths.
- The design avoids using color as the sole communication channel for status.
