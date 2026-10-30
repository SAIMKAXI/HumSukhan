import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, errorResponse, HttpError, json, readJson, requireUser } from "../_shared/guard.ts";

// Deepgram's own limit for one request. The app's longest text (a wellbeing
// idea read aloud) is about 400 characters.
const MAX_TEXT_CHARS = 2000;

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
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await readJson(req, 16 * 1024);
    const rawText = typeof body.text === "string" ? body.text.trim() : "";
    const language = typeof body.language === "string" ? body.language : "auto";
    if (!rawText) throw new HttpError(400, "Text is required");
    if (rawText.length > MAX_TEXT_CHARS) throw new HttpError(400, "Text is too long to speak in one request");

    const text = stripBlockedScript(rawText);
    if (!text) throw new HttpError(400, "No supported speech text remains after validation");

    const normalizedLanguage = language.toLowerCase().trim();
    if (["hindi", "hi"].includes(normalizedLanguage)) throw new HttpError(400, "Unsupported speech language");

    await requireUser(req, "speech");

    const provider = detectProvider(normalizedLanguage, text);
    const result = provider === "soniox"
      ? await synthesizeSoniox(text)
      : await synthesizeDeepgram(text);

    return json({
      provider: result.provider,
      mimeType: result.mimeType,
      audioBase64: toBase64(result.bytes),
    });
  } catch (error) {
    return errorResponse(error, "speech-synthesis error", "Speech synthesis is unavailable right now", 503);
  }
});
