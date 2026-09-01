# Conversation Module

## Ownership

Conversational Mode owns its presentation, conversation state, speech/STT integration, TTS integration, live caption UI, and conversation-specific tests.

## Current extraction

The implementation files are physically present under this module. The legacy `screens/`, `providers/`, and `services/` paths remain temporarily as compatibility locations until all application imports are migrated and the old feature-specific files can be removed safely.

## Next migration step

Update feature consumers and the application shell to import the public API from `conversation.dart`, then replace the legacy implementations with re-export shims and remove them after QA confirms no remaining dependency.
