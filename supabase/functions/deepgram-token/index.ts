import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const keys = () => [1, 2, 3]
  .map((i) => Deno.env.get(`DEEPGRAM_API_KEY_${i}`))
  .filter((v): v is string => Boolean(v?.trim()));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }

  const secretKeys = keys();
  if (secretKeys.length === 0) {
    return Response.json(
      { error: "Deepgram server keys are not configured." },
      { status: 503, headers: corsHeaders },
    );
  }

  let lastStatus = 502;
  let lastError = "Deepgram token request failed";

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
      return Response.json(
        {
          accessToken: body.access_token,
          expiresIn: body.expires_in ?? 3600,
        },
        { status: 200, headers: corsHeaders },
      );
    }

    lastStatus = response.status;
    lastError = await response.text();
    if (![401, 402, 403, 429].includes(response.status)) break;
  }

  return Response.json(
    {
      error: "Unable to issue a Deepgram temporary token.",
      detail: lastError,
    },
    { status: lastStatus, headers: corsHeaders },
  );
});
