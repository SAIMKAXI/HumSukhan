import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const GEMINI_MODEL = "gemini-2.5-flash";
const MAX_TRANSCRIPT_CHARS = 60000;
const MAX_SUMMARY_BULLETS = 6;
const MAX_ACTION_ITEMS = 8;
const MAX_DEADLINES = 8;
const MAX_MENTIONED_PEOPLE = 12;

const TASK_VERBS = new Set([
  "add", "approve", "book", "call", "check", "complete", "confirm",
  "contact", "create", "deliver", "discuss", "draft", "email", "finish", "follow",
  "fix", "implement", "prepare", "review", "schedule", "send", "share",
  "submit", "test", "update", "upload", "write",
]);

const COMMITMENT_MARKERS = [
  " will ", " should ", " must ", " need to ", " needs to ", " have to ",
  " has to ", " responsible for ", " follow up ",
];

const DISCUSSION_PREFIXES = [
  "discussed", "talked about", "mentioned", "noted ", "reviewed",
  "considered", "explored", "covered", "talked through", "agreed", "decided",
  "the deadline is", "deadline:", "context:", "background:",
];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

const cleanString = (value: unknown): string => String(value ?? "")
  .replace(/\s+/g, " ")
  .trim()
  .replace(/^(?:[•▪◦·*-]+|\d+[.)])\s*/, "")
  .trim();

const canonical = (value: string): string => value
  .toLocaleLowerCase()
  .replace(/[^\p{L}\p{N}\s]+/gu, " ")
  .replace(/\s+/g, " ")
  .trim();

const tokens = (value: string): Set<string> => new Set(
  value.split(" ").filter((token) => token.length >= 2),
);

const containsTaskSignal = (value: string): boolean => {
  const key = ` ${canonical(value)} `;
  if (COMMITMENT_MARKERS.some((marker) => key.includes(marker))) return true;

  const words = key.trim().split(" ");
  if (words.length > 0 && TASK_VERBS.has(words[0])) return true;
  for (let i = 0; i < words.length - 1; i += 1) {
    if ((words[i] === "to" || words[i] === "and") && TASK_VERBS.has(words[i + 1])) {
      return true;
    }
  }

  return /\b(follow up with|send .* by|complete .* by|finish .* by|deliver .* by)\b/.test(key);
};

const isActionable = (value: string): boolean => {
  const key = canonical(value);
  if (!key) return false;
  if (DISCUSSION_PREFIXES.some((prefix) => key === prefix || key.startsWith(`${prefix} `))) {
    return false;
  }
  return containsTaskSignal(key);
};

const cleanStringList = (value: unknown, maxItems: number): string[] => {
  if (!Array.isArray(value)) return [];

  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of value) {
    const text = cleanString(item);
    if (!text) continue;
    const key = canonical(text);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
};

const normalizeActionItems = (value: unknown): string[] => {
  const result: string[] = [];
  for (const item of cleanStringList(value, MAX_ACTION_ITEMS)) {
    if (!isActionable(item)) continue;

    const duplicate = result.some((existing) => {
      const a = tokens(canonical(existing));
      const b = tokens(canonical(item));
      if (a.size === 0 || b.size === 0) return true;
      const intersection = [...a].filter((token) => b.has(token)).length;
      const union = new Set([...a, ...b]).size;
      return union > 0 && intersection / union >= 0.80;
    });
    if (!duplicate) result.push(item);
  }
  return result;
};

const removeActionOverlap = (summaryBullets: string[], actionItems: string[]): string[] => {
  if (!summaryBullets.length || !actionItems.length) return summaryBullets;

  return summaryBullets.filter((summary) => {
    const summaryKey = canonical(summary);
    return !actionItems.some((action) => {
      const actionKey = canonical(action);
      if (summaryKey === actionKey) return true;
      const a = tokens(summaryKey);
      const b = tokens(actionKey);
      if (a.size < 3 || b.size < 3) return false;
      const intersection = [...a].filter((token) => b.has(token)).length;
      const union = new Set([...a, ...b]).size;
      return union > 0 && intersection / union >= 0.85 && summary.length <= action.length + 24;
    });
  });
};

const normalizeInsight = (result: any) => {
  const rawSummaryBullets = cleanStringList(result?.summaryBullets, MAX_SUMMARY_BULLETS);
  const actionItems = normalizeActionItems(result?.actionItems);
  const summaryBullets = removeActionOverlap(rawSummaryBullets, actionItems);
  const deadlines = cleanStringList(result?.deadlines, MAX_DEADLINES);
  const mentionedPeople = cleanStringList(result?.mentionedPeople, MAX_MENTIONED_PEOPLE);

  return {
    summary: summaryBullets.join(" "),
    summaryBullets,
    actionItems,
    deadlines,
    mentionedPeople,
  };
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

    const body = await req.json();
    const transcript = typeof body?.transcript === "string" ? body.transcript.trim() : "";
    if (!transcript) return json({ error: "Transcript is required" }, 400);

    const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    if (!apiKey) return json({ error: "AI service is not configured" }, 503);

    const sessionTitle = String(body?.sessionTitle ?? "Untitled").trim() || "Untitled";
    const sessionType = String(body?.sessionType ?? "class").toLowerCase();
    const typeLabel = sessionType === "meeting"
      ? "meeting"
      : sessionType === "lecture"
          ? "lecture"
          : "class";

    const boundedTranscript = transcript.length > MAX_TRANSCRIPT_CHARS
      ? `${transcript.slice(0, MAX_TRANSCRIPT_CHARS)}\n[Transcript truncated for summarization.]`
      : transcript;

    const prompt = [
      `You are the professional meeting intelligence layer for HumSukhan.`,
      `Analyze the ${typeLabel} transcript titled "${sessionTitle}".`,
      `Produce a factual executive summary, not a transcript rewrite.`,
      `Summarize the most important topics, decisions, outcomes, and conclusions.`,
      `Each summary bullet must be a concise synthesis of one or more transcript points.`,
      `Do not copy transcript sentences verbatim unless a very short quote is essential to meaning.`,
      `Do not include filler, greetings, repetition, or commentary about the summarization itself.`,
      `Action items are tasks someone is expected to perform after the session.`,
      `Only emit an action item when the transcript contains an explicit task, commitment, request, assignment, or follow-up.`,
      `Action items must be phrased as concrete work, not a topic, observation, decision, or discussion point.`,
      `Remove passive statements such as "the team discussed...", "the deadline is...", or "the project needs..." unless they contain an explicit follow-up task.`,
      `Imperative actions such as "Discuss the rollout plan" are valid tasks when explicitly requested or assigned.`,
      `When a person is explicitly assigned, keep that person's name in the action item.`,
      `When a deadline is explicitly attached to an action, keep the deadline in the same action item.`,
      `Never invent an owner or deadline.`,
      `Do not repeat an action in summaryBullets when the bullet is primarily the same task; keep richer decision/context summaries when they add meaningful context.`,
      `Deadlines must contain only explicit dates or time commitments from the transcript.`,
      `Mentioned people must contain only people actually named or clearly identified in the transcript.`,
      `Do not infer owners, deadlines, decisions, or facts that are not supported by the transcript.`,
      `Return ONLY valid JSON with exactly these fields:`,
      `summaryBullets (string[], 3-6 bullets when enough information exists),`,
      `actionItems (string[]), deadlines (string[]), mentionedPeople (string[]).`,
      `Keep each summary bullet under 30 words. Keep each action item concise, task-focused, and standalone.`,
      `Empty categories must be [].`,
      "",
      "Transcript:",
      boundedTranscript,
    ].join("\n");

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.15,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              properties: {
                summaryBullets: { type: "ARRAY", items: { type: "STRING" } },
                actionItems: { type: "ARRAY", items: { type: "STRING" } },
                deadlines: { type: "ARRAY", items: { type: "STRING" } },
                mentionedPeople: { type: "ARRAY", items: { type: "STRING" } },
              },
              required: ["summaryBullets", "actionItems", "deadlines", "mentionedPeople"],
            },
          },
        }),
      },
    );

    const raw = await response.text();
    if (!response.ok) {
      console.error("Gemini error", response.status, raw.slice(0, 1000));
      return json(
        { error: "AI provider request failed", providerStatus: response.status },
        response.status === 429 ? 429 : 502,
      );
    }

    let payload: any;
    try {
      payload = JSON.parse(raw);
    } catch {
      return json({ error: "AI provider returned invalid JSON" }, 502);
    }

    const text = payload?.candidates?.[0]?.content?.parts
      ?.map((part: any) => part?.text ?? "")
      .join("")
      .trim();
    if (!text) return json({ error: "AI provider returned no content" }, 502);

    let result: any;
    try {
      result = JSON.parse(text);
    } catch {
      return json({ error: "AI provider returned malformed insight JSON" }, 502);
    }

    const insight = normalizeInsight(result);
    if (insight.summaryBullets.length === 0 && insight.actionItems.length === 0 && insight.deadlines.length === 0) {
      return json({ error: "AI provider returned no usable insights" }, 502);
    }

    return json(insight);
  } catch (error) {
    console.error(error);
    return json({ error: "Unable to generate insights" }, 500);
  }
});
