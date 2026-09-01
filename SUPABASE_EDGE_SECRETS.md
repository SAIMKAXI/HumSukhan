# Supabase Edge Function secrets

These values belong in **Supabase Dashboard -> Edge Functions -> Secrets**. Never place the actual values in Flutter code, Git, or normal database tables.

## Speech synthesis

Deepgram English TTS:
- `DEEPGRAM_API_KEY_1`
- `DEEPGRAM_API_KEY_2`
- `DEEPGRAM_API_KEY_3`

Soniox Urdu TTS:
- `SONIOX_API_KEY_1`
- `SONIOX_API_KEY_2`
- `SONIOX_API_KEY_3`
- `SONIOX_API_KEY_4`

The `speech-synthesis` Edge Function rotates through the provider keys when a provider returns an authentication, quota, or rate-limit failure.

## Professional Mode AI insights

Gemini Flash:
- `GEMINI_API_KEY`

The `generate-insights` Edge Function uses `gemini-2.5-flash` for Professional session summaries, themes, action items, deadlines, vocabulary, and mentioned people.

## Client fallback

The Flutter app does not need any provider secret. When cloud synthesis cannot be used because the device is offline or all cloud attempts fail, the app falls back to the device's installed Flutter TTS voice for English or Urdu.
