# Changelog

## 2.3.0+19

### Speech reliability
- Hardened cloud TTS cancellation so obsolete requests cannot fall through into native playback.
- Stabilized overlapping Speak interruptions and listening resume behavior.
- Consolidated Deepgram `speech_final` handling so one utterance produces one finalized caption.
- Preserved finalized transcript text when a stream closes without an explicit `speech_final` packet.

### Account and data safety
- Isolated local conversation and professional session storage by signed-in user.
- Hardened account creation so an existing account cannot be overwritten through public signup.
- Kept Supabase RLS ownership policies enabled across application data tables.
- Added and cleaned foreign-key support indexes without leaving redundant duplicates.

### Release engineering
- Android release builds require a configured production keystore instead of debug signing.
- Release automation runs only from matching `vX.Y.Z` tags and verifies the tag against `pubspec.yaml`.
- Flutter analysis and the full Flutter test suite remain mandatory CI gates.
