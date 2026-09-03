import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEEPGRAM_KEYS = [
  Deno.env.get("DEEPGRAM_API_KEY_1"),
  Deno.env.get("DEEPGRAM_API_KEY_2"),
  Deno.env.get("DEEPGRAM_API_KEY_3"),
].filter((value): value is string => !!value?.trim());

const SONIOX_KEYS = [
  Deno.env.get("SONIOX_API_KEY_1"),
  Deno.env.get("SONIOX_API_KEY_2"),
  Deno.env.get("SONIOX_API_KEY_3"),
  Deno.env.get("SONIOX_API_KEY_4"),
].filter((value): value is string => !!value?.trim());

let deepgramCursor = 0;
let sonioxCursor = 0;

function corsJson(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function stripBlockedScript(text: string): string {
  return text
    .replace(/[\u0900-\u097F]+/gu, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function containsUrdu(text: string): boolean {
  return /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/u.test(text);
}

function detectProvider(language: string, text: string): "soniox" | "deepgram" {
  const normalized = language.toLowerCase().trim();
  if (normalized === "urdu" || normalized === "roman urdu") return "soniox";
  if (normalized === "auto" && containsUrdu(text)) return "soniox";
  return "deepgram";
}

function detectSonioxLanguage(language: string, text: string): "ur" {
  return "ur";
}

async function synthesizeDeepgram(text: string) {
  if (DEEPGRAM_KEYS.length === 0) throw new Error("Deepgram TTS is not configured");
  let lastStatus = 502;
  for (let attempt = 0; attempt < DEEPGRAM_KEYS.length; attempt += 1) {
    const index = (deepgramCursor + attempt) % DEEPGRAM_KEYS.length;
    const key = DEEPGRAM_KEYS[index];
    const response = await fetch(
      "https://api.deepgram.com/v2/speak?model=flux-hannah-en&encoding=mp3",
      {
        method: "POST",
        headers: { Authorization: `Token ${key}`, "Content-Type": "application/json" },
        body: JSON.stringify({ text, speed: 1, expressivity: 0 }),
      },
    );
    if (response.ok) {
      deepgramCursor = index;
      return {
        provider: "deepgram",
        mimeType: response.headers.get("content-type") ?? "audio/mpeg",
        bytes: new Uint8Array(await response.arrayBuffer()),
      };
    }
    lastStatus = response.status;
    if (![401, 402, 403, 429].includes(response.status)) break;
  }
  throw new Error(`Deepgram TTS failed (${lastStatus})`);
}

async function synthesizeSoniox(text: string) {
  if (SONIOX_KEYS.length === 0) throw new Error("Soniox TTS is not configured");
  let lastStatus = 502;
  for (let attempt = 0; attempt < SONIOX_KEYS.length; attempt += 1) {
    const index = (sonioxCursor + attempt) % SONIOX_KEYS.length;
    const key = SONIOX_KEYS[index];
    const response = await fetch("https://tts-rt.soniox.com/tts", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tts-rt-v2",
        language: "ur",
        voice: "Daniel",
        audio_format: "mp3",
        text,
        speed: 1,
        reduce_silence: true,
      }),
    });
    if (response.ok) {
      sonioxCursor = index;
      return {
        provider: "soniox",
        mimeType: response.headers.get("content-type") ?? "audio/mpeg",
        bytes: new Uint8Array(await response.arrayBuffer()),
      };
    }
    lastStatus = response.status;
    if (![401, 402, 403, 429].includes(response.status)) break;
  }
  throw new Error(`Soniox TTS failed (${lastStatus})`);
}

function toBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(
      ...bytes.subarray(offset, Math.min(offset + chunkSize, bytes.length)),
    );
  }
  return btoa(binary);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return corsJson({ error: "Unauthorized" }, 401);

    const body = await req.json();
    const rawText = typeof body?.text === "string" ? body.text.trim() : "";
    const language = typeof body?.language === "string" ? body.language : "auto";
    if (!rawText) return corsJson({ error: "Text is required" }, 400);

    const text = stripBlockedScript(rawText);
    if (!text) return corsJson({ error: "No supported speech text remains after validation" }, 400);

    const normalizedLanguage = language.toLowerCase().trim();
    if (["hindi", "hi"].includes(normalizedLanguage)) {
      return corsJson({ error: "Unsupported speech language" }, 400);
    }

    const provider = detectProvider(normalizedLanguage, text);
    const result = provider === "soniox"
      ? await synthesizeSoniox(text)
      : await synthesizeDeepgram(text);

    return corsJson({
      provider: result.provider,
      mimeType: result.mimeType,
      audioBase64: toBase64(result.bytes),
    });
  } catch (error) {
    console.error(error);
    return corsJson({ error: error instanceof Error ? error.message : "Speech synthesis failed" }, 503);
  }
});
