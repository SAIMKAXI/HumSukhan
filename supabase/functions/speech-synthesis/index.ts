import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const getKeys = (prefix: string, count: number) =>
  Array.from({ length: count }, (_, index) => Deno.env.get(`${prefix}_${index + 1}`) ?? "")
    .map((key) => key.trim())
    .filter(Boolean);

const looksLikeUrdu = (text: string, language: string) => {
  const normalized = language.toLowerCase().trim();
  if (["urdu", "roman urdu", "ur", "ur-pk"].includes(normalized)) return true;
  if (/[؀-ۿ]/.test(text)) return true;
  const tokens = text.toLowerCase().replace(/[^a-z0-9\s']/g, " ").split(/\s+/).filter(Boolean);
  const romanUrdu = new Set([
    "aap", "ap", "aapko", "aapki", "aapke", "aapka", "kya", "kyun", "hai", "hain",
    "ho", "mein", "main", "mujhe", "tum", "se", "ko", "ka", "ki", "ke", "yeh", "woh",
    "ham", "hum", "mera", "meri", "mere", "apna", "nahi", "nahin", "acha", "achha",
    "theek", "karo", "karna", "jana", "jao", "chahiye", "bhi", "par",
  ]);
  return tokens.filter((token) => romanUrdu.has(token)).length >= 1;
};

const bytesToBase64 = (bytes: Uint8Array) => {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunkSize, bytes.length)));
  }
  return btoa(binary);
};

async function speakWithDeepgram(text: string) {
  const keys = getKeys("DEEPGRAM_API_KEY", 3);
  if (keys.length === 0) throw new Error("No Deepgram TTS keys are configured on the server.");

  let lastStatus = 500;
  for (const key of keys) {
    const response = await fetch(
      "https://api.deepgram.com/v2/speak?model=flux-hannah-en&speed=1&expressivity=0",
      {
        method: "POST",
        headers: {
          Authorization: `Token ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ text }),
      },
    );

    if (response.ok) {
      const bytes = new Uint8Array(await response.arrayBuffer());
      return {
        audioBase64: bytesToBase64(bytes),
        mimeType: response.headers.get("content-type") ?? "audio/mpeg",
        provider: "deepgram",
        language: "en",
      };
    }

    lastStatus = response.status;
    if (![401, 402, 403, 429].includes(response.status)) {
      const detail = await response.text();
      throw new Error(`Deepgram TTS failed (${response.status}): ${detail}`);
    }
  }
  throw new Error(`All configured Deepgram TTS keys are unavailable (${lastStatus}).`);
}

async function speakWithSoniox(text: string) {
  const keys = getKeys("SONIOX_API_KEY", 4);
  if (keys.length === 0) throw new Error("No Soniox TTS keys are configured on the server.");

  let lastStatus = 500;
  for (const key of keys) {
    const response = await fetch("https://tts-rt.soniox.com/tts", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tts-rt-v2",
        language: "ur",
        voice: "Adrian",
        audio_format: "mp3",
        text,
        speed: 1,
      }),
    });

    if (response.ok) {
      const bytes = new Uint8Array(await response.arrayBuffer());
      return {
        audioBase64: bytesToBase64(bytes),
        mimeType: response.headers.get("content-type") ?? "audio/mpeg",
        provider: "soniox",
        language: "ur",
      };
    }

    lastStatus = response.status;
    if (![401, 402, 403, 429].includes(response.status)) {
      const detail = await response.text();
      throw new Error(`Soniox TTS failed (${response.status}): ${detail}`);
    }
  }
  throw new Error(`All configured Soniox TTS keys are unavailable (${lastStatus}).`);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const text = typeof body?.text === "string" ? body.text.trim() : "";
    const language = typeof body?.language === "string" ? body.language : "English";

    if (!text) return Response.json({ error: "text is required" }, { status: 400, headers: corsHeaders });
    if (text.length > 5000) return Response.json({ error: "text is too long" }, { status: 400, headers: corsHeaders });

    const result = looksLikeUrdu(text, language)
      ? await speakWithSoniox(text)
      : await speakWithDeepgram(text);

    return Response.json(result, { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("speech-synthesis error", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Speech synthesis failed" },
      { status: 500, headers: corsHeaders },
    );
  }
});
