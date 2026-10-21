begin;

-- Keep reusable AI insights, but stop retaining transcripts and session metadata
-- in Supabase. Insight rows become keyed by the device-generated session UUID.
alter table public.insights
  add column if not exists expires_at timestamptz;

-- Carry forward each insight's existing session retention deadline before
-- deleting the cloud sessions. Orphaned legacy insights get a 15-day lifetime.
update public.insights i
set expires_at = coalesce(s.expires_at, i.generated_at + interval '15 days')
from public.sessions s
where i.session_id = s.id
  and i.expires_at is null;

update public.insights
set expires_at = coalesce(expires_at, generated_at + interval '15 days')
where expires_at is null;

-- Phase 3 cleanup: discard insights already beyond their original retention
-- window; keep valid summaries/action items for users to retrieve from cloud.
delete from public.insights
where expires_at <= now();

alter table public.insights
  alter column expires_at set default (now() + interval '15 days'),
  alter column expires_at set not null;

-- Remove legacy duplicate insight rows before enforcing one result per session.
with ranked as (
  select ctid,
         row_number() over (
           partition by session_id
           order by generated_at desc nulls last, id desc
         ) as rn
  from public.insights
)
delete from public.insights i
using ranked r
where i.ctid = r.ctid and r.rn > 1;

-- The app upserts by session_id, so make that conflict target explicit.
create unique index if not exists insights_session_id_unique_idx
  on public.insights (session_id);

-- The old non-unique index duplicates the new unique index.
drop index if exists public.idx_insights_session_id;

-- Insights must survive removal of their local-only parent session row.
alter table public.insights
  drop constraint if exists insights_session_id_fkey;

-- These RPCs only existed to mutate the cloud session/folder tables.
drop function if exists public.delete_professional_folder(uuid);
drop function if exists public.delete_professional_folder_and_sessions(uuid);

-- No conversation transcripts, professional transcripts, sessions, or folders
-- should remain in the cloud database. Auth users and profile/settings tables
-- are intentionally untouched.
delete from public.captions;
delete from public.sessions;
delete from public.folders;

drop table if exists public.captions;
drop table if exists public.sessions;
drop table if exists public.folders;

commit;
