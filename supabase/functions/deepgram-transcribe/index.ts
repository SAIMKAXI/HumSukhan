import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const keys = () => [1, 2, 3]
  .map((i) => Deno.env.get(`DEEPGRAM_API_KEY_${i}`))
  .filter((v): v is string => Boolean(v && v.trim()));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const audioBase64 = typeof body?.audioBase64 === "string" ? body.audioBase64 : "";
    const mimeType = typeof body?.mimeType === "string" ? body.mimeType : "audio/wav";
    const language = typeof body?.language === "string" ? body.language : "ur";

    if (!audioBase64) {
      return Response.json({ error: "audioBase64 is required" }, { status: 400, headers: corsHeaders });
    }

    const secretKeys = keys();
    if (secretKeys.length === 0) {
      return Response.json({ error: "Deepgram server keys are not configured." }, { status: 503, headers: corsHeaders });
    }

    const audio = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
    const params = new URLSearchParams({
      model: "nova-3",
      smart_format: "true",
      punctuate: "true",
      language,
      encoding: "linear16",
      sample_rate: String(body?.sampleRate ?? 16000),
      channels: String(body?.channels ?? 1),
    });

    let lastStatus = 500;
    let lastError = "Deepgram request failed";
    for (const key of secretKeys) {
      const response = await fetch(`https://api.deepgram.com/v1/listen?${params}`, {
        method: "POST",
        headers: {
          Authorization: `Token ${key}`,
          "Content-Type": mimeType,
        },
        body: audio,
      });

      if (response.ok) {
        const payload = await response.json();
        const transcript = payload?.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "";
        return Response.json(
          { transcript, provider: "deepgram", language },
          { status: 200, headers: corsHeaders },
        );
      }

      lastStatus = response.status;
      lastError = await response.text();
      if (![401, 402, 403, 429].includes(response.status)) break;
    }

    return Response.json(
      { error: "All configured Deepgram keys were rejected or exhausted.", detail: lastError },
      { status: lastStatus, headers: corsHeaders },
    );
  } catch (error) {
    console.error("deepgram-transcribe error", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Transcription failed" },
      { status: 500, headers: corsHeaders },
    );
  }
});
