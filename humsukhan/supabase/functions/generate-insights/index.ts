import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { transcript, sessionTitle, sessionType } = await req.json();
    if (typeof transcript !== "string" || !transcript.trim()) {
      return new Response(JSON.stringify({ error: "Transcript is required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return new Response(JSON.stringify({ error: "AI service is not configured" }), { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const model = "gemini-2.5-flash";
    const typeLabel = sessionType === "meeting" ? "meeting" : sessionType === "lecture" ? "lecture" : "class";
    const prompt = `You are an AI assistant analyzing a ${typeLabel} transcript titled "${String(sessionTitle ?? "Untitled")}".
Return ONLY valid JSON with summary, vocabulary, themes, actionItems, deadlines, and mentionedPeople.
Base everything strictly on the transcript. Do not fabricate information. Empty data must be [].

Transcript:\n${transcript}`;

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { temperature: 0.3, maxOutputTokens: 2048 } }),
    });
    if (!response.ok) return new Response(JSON.stringify({ error: "AI provider request failed" }), { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const payload = await response.json();
    const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") return new Response(JSON.stringify({ error: "AI provider returned no content" }), { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const cleaned = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
    const result = JSON.parse(cleaned);
    return new Response(JSON.stringify(result), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: "Unable to generate insights" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
