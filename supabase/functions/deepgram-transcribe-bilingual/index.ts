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

function stripBlockedScript(text: string): string {
  return text.replace(/[\u0900-\u097F]+/gu, " ").replace(/\s{2,}/g, " ").trim();
}

async function transcribe(
  key: string,
  audio: Uint8Array,
  mimeType: string,
  language: string,
  sampleRate: number,
  channels: number,
) {
  const params = new URLSearchParams({
    model: "nova-3",
    smart_format: "true",
    punctuate: "true",
    language,
    encoding: "linear16",
    sample_rate: String(sampleRate),
    channels: String(channels),
  });
  const response = await fetch(`https://api.deepgram.com/v1/listen?${params}`, {
    method: "POST",
    headers: { Authorization: `Token ${key}`, "Content-Type": mimeType },
    body: audio,
  });
  if (!response.ok) return { ok: false, status: response.status, error: await response.text() };
  const payload = await response.json();
  const alternative = payload?.results?.channels?.[0]?.alternatives?.[0];
  return {
    ok: true,
    status: 200,
    transcript: stripBlockedScript(alternative?.transcript ?? ""),
    confidence: Number(alternative?.confidence ?? 0),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  try {
    const body = await req.json();
    const audioBase64 = typeof body?.audioBase64 === "string" ? body.audioBase64 : "";
    const mimeType = typeof body?.mimeType === "string" ? body.mimeType : "audio/wav";
    const requestedLanguage = typeof body?.language === "string" ? body.language.toLowerCase() : "auto";
    const sampleRate = Number(body?.sampleRate ?? 16000);
    const channels = Number(body?.channels ?? 1);
    if (!audioBase64) return Response.json({ error: "audioBase64 is required" }, { status: 400, headers: corsHeaders });
    if (!["auto", "multi", "english", "en", "urdu", "ur", "roman urdu"].includes(requestedLanguage)) {
      return Response.json({ error: "Unsupported transcription language" }, { status: 400, headers: corsHeaders });
    }

    const secretKeys = keys();
    if (secretKeys.length === 0) return Response.json({ error: "Deepgram server keys are not configured." }, { status: 503, headers: corsHeaders });
    const audio = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
    const candidates = requestedLanguage === "auto" || requestedLanguage === "multi"
      ? ["en", "ur"]
      : [requestedLanguage === "english" ? "en" : requestedLanguage === "urdu" || requestedLanguage === "roman urdu" ? "ur" : requestedLanguage];

    let best: { transcript: string; confidence: number; language: string } | null = null;
    let lastStatus = 500;
    let lastError = "Deepgram request failed";
    for (const key of secretKeys) {
      let keyRejected = false;
      for (const language of candidates) {
        const result = await transcribe(key, audio, mimeType, language, sampleRate, channels);
        lastStatus = result.status;
        if (!result.ok) {
          lastError = result.error;
          if ([401, 402, 403, 429].includes(result.status)) { keyRejected = true; break; }
          continue;
        }
        const transcript = result.transcript.trim();
        if (!transcript) continue;
        if (best == null || result.confidence > best.confidence) {
          best = { transcript, confidence: result.confidence, language };
        }
      }
      if (best != null) break;
      if (keyRejected) continue;
    }

    if (best != null) {
      return Response.json({
        transcript: best.transcript,
        provider: "deepgram",
        language: best.language,
        detectedLanguage: best.language,
        confidence: best.confidence,
      }, { status: 200, headers: corsHeaders });
    }
    return Response.json({ error: "All configured Deepgram keys were rejected or exhausted.", detail: lastError }, { status: lastStatus, headers: corsHeaders });
  } catch (error) {
    console.error("deepgram-transcribe-bilingual error", error);
    return Response.json({ error: error instanceof Error ? error.message : "Transcription failed" }, { status: 500, headers: corsHeaders });
  }
});
