# Backend

HumSukhan uses [Supabase](https://supabase.com) for authentication, a small Postgres database and the Edge Functions that call third-party AI services. The app ships only the project URL and its public anon key. Every other key is an Edge Function secret.

## Database

Four tables, each protected by row-level security so that a signed-in user can read and write only their own rows. Check constraints cap the size of every text and JSON column well above what the app writes, so one account cannot fill the database.

| Table | Contents |
|---|---|
| `profiles` | Name, avatar, preferred language; one row per account |
| `settings` | The user's app settings as JSON, so they follow the account to a new phone |
| `quick_replies` | The user's quick replies, with category and star |
| `insights` | AI insights for a Professional session: summary bullets, action items, deadlines, mentioned people. One row per session, with an `expires_at` that matches the session's retention. |

Professional transcripts, sessions and folders are not stored in Supabase. They stay on the phone, and an insight refers to its session only by the session's ID. Conversational transcripts are never stored anywhere.

The schema is defined by the SQL files in `supabase/migrations/`, applied in order.

### Usage limits

The `private.request_counts` table counts requests per user per minute and per day. Nothing outside the database can read it.

- **`use_request_quota(action)`** is called by the paid Edge Functions with the caller's own token. It answers:
  - `ok`
  - `limited`
  - `signed_out`, for no user or an anonymous user. The anon key may not call it at all.
- **`use_signup_quota(address)`** is callable only with the service role. It limits sign-ups:
  - 5 an hour and 20 a day from one network address
  - 60 an hour in total

| Action | Per minute | Per day |
|---|---|---|
| `transcribe` | 60 | 5000 |
| `speech` | 60 | 3000 |
| `insights` | 10 | 200 |
| `deepgram-token` | 20 | 300 |

To change a limit, add a migration that replaces `use_request_quota`.

## Edge Functions

| Function | Called by the app to | Provider |
|---|---|---|
| `create-account` | Create an account without overwriting an existing one | Supabase Auth (admin) |
| `deepgram-token` | Get a short-lived token for the live Deepgram stream | Deepgram |
| `deepgram-transcribe` | Recognize one recorded sentence in English or Urdu | Deepgram |
| `deepgram-transcribe-bilingual` | Recognize one recorded sentence as English or Urdu, whichever fits better | Deepgram |
| `speech-synthesis` | Speak text when the phone has no voice for the language | Deepgram (English), Soniox (Urdu) |
| `speech-synthesis-v2` | Second voice service, used if `speech-synthesis` fails | Deepgram (English), Soniox (Urdu) |
| `generate-insights-v2` | Turn a session transcript into insights | Google Gemini Flash |

The app calls `create-account` with the anon key, and the others with the signed-in user's session.

The Functions gateway accepts the public anon key, so each paid function also checks the caller itself, in `supabase/functions/_shared/guard.ts`. Before calling a provider, it:

- refuses anyone who is not a signed-in, non-anonymous user (401)
- applies the usage limits above (429)
- refuses bodies, audio and text over a size limit (413 or 400)

It returns only its own error messages; provider responses and internal errors go to the function log.

`create-account`:

- applies the sign-up limit
- accepts passwords of 8 to 72 characters with upper and lower case letters, a digit and a symbol
- caps names at 100 characters

`deno test --allow-env --allow-read --allow-net supabase/functions/tests/` runs the security tests, which CI also runs. Deploy with `supabase functions deploy`. Functions that share `_shared/` must be redeployed after it changes.

## Secrets

Set these in the Supabase Dashboard under **Edge Functions → Secrets**. Never commit them or put them in the app.

| Secret | Used by |
|---|---|
| `DEEPGRAM_API_KEY_1` … `DEEPGRAM_API_KEY_3` | `deepgram-token`, `deepgram-transcribe`, `deepgram-transcribe-bilingual`, `speech-synthesis`, `speech-synthesis-v2` |
| `SONIOX_API_KEY_1` … `SONIOX_API_KEY_4` | `speech-synthesis`, `speech-synthesis-v2` |
| `GEMINI_API_KEY` | `generate-insights-v2` |
| `GEMINI_MODEL` (optional) | `generate-insights-v2`: comma-separated list of Gemini models to try in order. The default is `gemini-3.5-flash,gemini-3-flash-preview,gemini-2.5-flash`; a model Google reports as unavailable is skipped. |
| `SUPABASE_SERVICE_ROLE_KEY` | `create-account` (provided by Supabase) |

Where several keys of one provider are set, the functions try them in turn: a key that is rejected, out of credit or rate-limited hands over to the next.

## Authentication settings

On the Pro plan or above, turn on **Authentication → Providers → Email → Prevent use of leaked passwords**, so passwords found in known breaches are refused.

Password reset emails send the user back to the app through the deep link `com.humsukhan.humsukhan://login-callback/`. Add it under **Authentication → URL Configuration → Redirect URLs**; without it, Supabase sends the user to the project's Site URL instead.
