// Deployed in place of Edge Functions the app no longer calls
// (generate-insights, speech-synthesis-prod), so their old code, which
// accepted the public anon key, no longer runs. Delete them from the
// Supabase dashboard (Edge Functions) to remove them for good.
Deno.serve(() =>
  new Response(JSON.stringify({ error: "This service has been retired. Please update HumSukhan." }), {
    status: 410,
    headers: { "Content-Type": "application/json" },
  })
);
