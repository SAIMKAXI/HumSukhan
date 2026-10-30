// Checks every Edge Function makes before doing paid work: who is calling,
// how often (use_request_quota in the database), and how much they send.

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** A refusal whose message is safe to show the caller. */
export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

/**
 * The response for a failed request. A HttpError's own message is returned;
 * anything else is logged and answered generically, so provider responses,
 * keys and stack traces never reach the caller.
 */
export function errorResponse(error: unknown, label: string, fallback: string, status = 500): Response {
  if (error instanceof HttpError) return json({ error: error.message }, error.status);
  console.error(label, error);
  return json({ error: fallback }, status);
}

/**
 * Parses a JSON request body of at most maxBytes. Reading stops as soon as
 * the limit is passed, so an oversized body is never held in memory.
 */
export async function readJson(req: Request, maxBytes: number): Promise<Record<string, unknown>> {
  const declared = Number(req.headers.get("content-length") ?? "");
  if (Number.isFinite(declared) && declared > maxBytes) throw new HttpError(413, "Request is too large");
  if (!req.body) throw new HttpError(400, "Request body is required");

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      throw new HttpError(413, "Request is too large");
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new HttpError(400, "Request body must be JSON");
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError(400, "Request body must be a JSON object");
  }
  return body as Record<string, unknown>;
}

export type QuotaAction = "transcribe" | "speech" | "insights" | "deepgram-token";

/**
 * Lets the request through only for a signed-in account that has requests
 * left for this action. The Functions gateway accepts the public anon key
 * that ships inside the app, so its check alone would let anyone spend the
 * provider credits; use_request_quota runs as the caller and refuses anyone
 * who is not a signed-in, non-anonymous user.
 */
export async function requireUser(req: Request, action: QuotaAction): Promise<void> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer \S+$/.test(authorization)) throw new HttpError(401, "Sign in to use this feature");

  const url = Deno.env.get("SUPABASE_URL");
  const apiKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !apiKey) {
    console.error("requireUser: SUPABASE_URL or SUPABASE_ANON_KEY is not set");
    throw new HttpError(503, "Service is not configured");
  }

  let response: Response;
  try {
    response = await fetch(`${url}/rest/v1/rpc/use_request_quota`, {
      method: "POST",
      headers: { apikey: apiKey, Authorization: authorization, "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
      signal: AbortSignal.timeout(5000),
    });
  } catch (error) {
    console.error("Quota check could not be made", error);
    throw new HttpError(503, "Service is busy. Please try again shortly.");
  }

  // An invalid or expired token, or the anon key (which may not run the
  // function), is refused by the database API itself.
  if (response.status === 401 || response.status === 403) {
    await response.body?.cancel();
    throw new HttpError(401, "Sign in to use this feature");
  }
  if (!response.ok) {
    console.error("Quota check failed", response.status, (await response.text()).slice(0, 300));
    throw new HttpError(503, "Service is busy. Please try again shortly.");
  }

  const verdict = await response.json().catch(() => null);
  if (verdict === "ok") return;
  if (verdict === "signed_out") throw new HttpError(401, "Sign in to use this feature");
  if (verdict === "limited") throw new HttpError(429, "Too many requests. Please wait a minute and try again.");
  console.error("Quota check returned", verdict);
  throw new HttpError(503, "Service is busy. Please try again shortly.");
}

/**
 * The caller's network address as the Supabase edge reports it. Used only
 * to count sign-ups; a missing or forged value still falls under the
 * all-callers limit in use_signup_quota.
 */
export function clientAddress(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0];
  return (req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? forwarded ?? "unknown")
    .trim()
    .slice(0, 64) || "unknown";
}
