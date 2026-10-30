import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, errorResponse, HttpError, json, requireUser } from "../_shared/guard.ts";

const keys = () => [1, 2, 3]
  .map((i) => Deno.env.get(`DEEPGRAM_API_KEY_${i}`))
  .filter((v): v is string => Boolean(v?.trim()));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    // The token lets its holder stream audio to Deepgram on this project's
    // account for an hour, so only signed-in users get one.
    await requireUser(req, "deepgram-token");

    const secretKeys = keys();
    if (secretKeys.length === 0) throw new HttpError(503, "Deepgram server keys are not configured.");

    let lastStatus = 502;
    for (const key of secretKeys) {
      const response = await fetch("https://api.deepgram.com/v1/auth/grant", {
        method: "POST",
        headers: {
          Authorization: `Token ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl_seconds: 3600 }),
      });

      if (response.ok) {
        const body = await response.json();
        return json({
          accessToken: body.access_token,
          expiresIn: body.expires_in ?? 3600,
        });
      }

      lastStatus = response.status;
      console.error("Deepgram token request failed", response.status, (await response.text()).slice(0, 300));
      if (![401, 402, 403, 429].includes(response.status)) break;
    }

    return json({ error: "Unable to issue a Deepgram temporary token." }, lastStatus === 429 ? 429 : 502);
  } catch (error) {
    return errorResponse(error, "deepgram-token error", "Unable to issue a Deepgram temporary token.", 502);
  }
});
