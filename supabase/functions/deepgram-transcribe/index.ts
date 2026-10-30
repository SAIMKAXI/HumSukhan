import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, errorResponse, HttpError, json, readJson, requireUser } from "../_shared/guard.ts";

// The app sends one spoken phrase at a time, at most 12 seconds of 16 kHz
// mono 16-bit audio (about 384 KB). Allow a minute of it.
const MAX_AUDIO_BYTES = 2 * 1024 * 1024;
const MAX_BODY_BYTES = Math.ceil(MAX_AUDIO_BYTES * 4 / 3) + 4096;
const AUDIO_TYPES = new Set(["audio/wav", "audio/wave", "audio/x-wav", "audio/l16", "audio/pcm"]);

const keys = () => [1, 2, 3]
  .map((i) => Deno.env.get(`DEEPGRAM_API_KEY_${i}`))
  .filter((v): v is string => Boolean(v && v.trim()));

function stripBlockedScript(text: string): string {
  return text.replace(/[\u0900-\u097F]+/gu, " ").replace(/\s{2,}/g, " ").trim();
}

async function transcribe(key: string, audio: Uint8Array, mimeType: string, language: string, sampleRate: number, channels: number) {
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
    // Uint8Array.from gave the audio a buffer of its own, exactly its size.
    body: audio.buffer as ArrayBuffer,
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
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await readJson(req, MAX_BODY_BYTES);
    const audioBase64 = typeof body.audioBase64 === "string" ? body.audioBase64 : "";
    const mimeType = typeof body.mimeType === "string" ? body.mimeType.toLowerCase().trim() : "audio/wav";
    const requestedLanguage = typeof body.language === "string" ? body.language.toLowerCase().trim() : "auto";
    const sampleRate = Number(body.sampleRate ?? 16000);
    const channels = Number(body.channels ?? 1);

    if (!audioBase64) throw new HttpError(400, "audioBase64 is required");
    if (!["auto", "multi", "english", "en", "urdu", "ur", "roman urdu"].includes(requestedLanguage)) {
      throw new HttpError(400, "Unsupported transcription language");
    }
    if (!AUDIO_TYPES.has(mimeType)) throw new HttpError(400, "Unsupported audio type");
    if (!Number.isInteger(sampleRate) || sampleRate < 8000 || sampleRate > 48000) {
      throw new HttpError(400, "Unsupported sample rate");
    }
    if (channels !== 1 && channels !== 2) throw new HttpError(400, "Unsupported channel count");

    let audio: Uint8Array;
    try {
      audio = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
    } catch {
      throw new HttpError(400, "audioBase64 is not valid base64");
    }
    if (audio.byteLength > MAX_AUDIO_BYTES) throw new HttpError(413, "Audio is too long");

    await requireUser(req, "transcribe");

    const secretKeys = keys();
    if (secretKeys.length === 0) throw new HttpError(503, "Deepgram server keys are not configured.");

    const candidates = requestedLanguage === "auto" || requestedLanguage === "multi"
      ? ["en", "ur"]
      : [requestedLanguage === "english" ? "en" : requestedLanguage === "urdu" || requestedLanguage === "roman urdu" ? "ur" : requestedLanguage];

    let best: { transcript: string; confidence: number; language: string } | null = null;
    let lastStatus = 500;

    for (const key of secretKeys) {
      let keyRejected = false;
      for (const language of candidates) {
        const result = await transcribe(key, audio, mimeType, language, sampleRate, channels);
        lastStatus = result.status;
        if (!result.ok) {
          console.error("Deepgram transcription failed", result.status, String(result.error).slice(0, 300));
          if ([401, 402, 403, 429].includes(result.status)) { keyRejected = true; break; }
          continue;
        }
        const transcript = (result.transcript ?? "").trim();
        if (!transcript) continue;
        const confidence = result.confidence ?? 0;
        if (best == null || confidence > best.confidence) best = { transcript, confidence, language };
      }
      if (best != null) break;
      if (keyRejected) continue;
    }

    if (best != null) {
      return json({
        transcript: best.transcript,
        provider: "deepgram",
        language: best.language,
        detectedLanguage: best.language,
        confidence: best.confidence,
      });
    }

    if (lastStatus === 200) return json({ transcript: "", provider: "deepgram" });
    return json({ error: "Transcription is unavailable right now." }, lastStatus === 429 ? 429 : 502);
  } catch (error) {
    return errorResponse(error, "deepgram-transcribe error", "Transcription failed");
  }
});
