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

The `generate-insights-v2` Edge Function writes Professional Mode summaries, action items, deadlines and mentioned people. It tries `gemini-3.5-flash`, then `gemini-3-flash-preview`, then `gemini-2.5-flash`, moving on when Google answers that a model is not available to the key. To choose the models, set the optional `GEMINI_MODEL` secret to a comma-separated list.

## Speech backups

The same Deepgram and Soniox keys serve the cloud backups the app falls back to when the device has no recognizer or voice for a language:

- `deepgram-token` — a short-lived token for the live Deepgram stream.
- `deepgram-transcribe` / `deepgram-transcribe-bilingual` — recorded-utterance recognition (fixed language / English + Urdu) when the live stream cannot be used.
- `speech-synthesis-v2` — second cloud voice, tried when `speech-synthesis` fails.

## Local fallback

The app captions with the device's own recognizer first when it has the language installed, then with the cloud, then with an offline model downloaded in Settings (English streaming Zipformer; Urdu Whisper base). In Auto (English and Urdu together) the cloud goes first, since a device recognizer listens in one language only.

The app speaks with the device's own voice first and uses the cloud voices only when the device has none for the language, so speech works offline wherever a voice is installed. No cloud API secret is needed in the app binary.
