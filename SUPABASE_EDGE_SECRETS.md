# Supabase Edge Function secrets

Set these values in Supabase Dashboard -> Edge Functions -> Secrets. Never commit actual secret values to Git or embed them in the Flutter app.

## TTS

Deepgram English:
- `DEEPGRAM_API_KEY_1`
- `DEEPGRAM_API_KEY_2`
- `DEEPGRAM_API_KEY_3`

Soniox Urdu:
- `SONIOX_API_KEY_1`
- `SONIOX_API_KEY_2`
- `SONIOX_API_KEY_3`
- `SONIOX_API_KEY_4`

## Professional AI insights

Gemini Flash:
- `GEMINI_API_KEY`

The `generate-insights-v2` Edge Function uses `gemini-2.5-flash` for Professional Mode summaries, action items, deadlines and mentioned people.

## Speech backups

The same Deepgram and Soniox keys serve the cloud backups the app falls back to when the device has no recognizer or voice for a language:

- `deepgram-transcribe` / `deepgram-transcribe-bilingual` — recorded-utterance recognition (fixed language / English + Urdu) when the live `deepgram-token` stream is unavailable and the device recognizer lacks the language.
- `speech-synthesis-v2` — second cloud voice, tried when `speech-synthesis` fails.

## Local fallback

The app speaks with the device's own voice first and uses the cloud voices only when the device has none for the language, so speech works offline wherever a voice is installed. No cloud API secret is needed in the app binary.
