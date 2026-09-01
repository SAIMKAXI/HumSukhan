# Conversation Mode User Experience Contract

Idle: show a clear `Tap microphone to speak` action.

Listening: show only `Listening…` with a subtle microphone/wave state. Interim speech-recognition text is consumed internally but is never rendered.

Speaker stops: emit exactly one finalized caption bubble containing speaker, complete text, language, time, and Speak action.

Primary microphone interaction is tap-to-toggle: Idle -> Starting -> Listening -> finalization -> Listening/Idle.

Cloud TTS is preferred. Flutter TTS/device speech is the fallback and must be ready before release.

Auto supports mixed Urdu/English recognition; English and Urdu remain explicit selectable modes.

Every visible state must have actionable recovery for permission, recorder, network, and speech-service failures.