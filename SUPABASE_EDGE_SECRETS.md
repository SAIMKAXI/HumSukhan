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

The existing `generate-insights` Edge Function uses `gemini-2.5-flash` for Professional Mode summaries, themes, action items, deadlines, vocabulary, and mentioned people.

## Local fallback

The Flutter app uses its installed system TTS voice when the device is offline or when the cloud TTS path cannot synthesize speech. No cloud API secret is needed in the app binary.
