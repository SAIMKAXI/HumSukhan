begin;

-- Preserve unexpired AI outputs, but do not retain cloud transcript/session data.
alter table public.insights
  add column if not exists expires_at timestamptz;

-- Upgrade existing AI insight records with the session's local retention deadline.
update public.insights as i
set expires_at = s.expires_at
from public.sessions as s
where i.session_id = s.id
  and i.expires_at is null;

-- Keep legacy summary content represented in the structured summary field before
-- changing the app's storage behavior. The summary column is retained for older
-- installed app builds during rollout.
update public.insights
set summary_bullets = case
  when jsonb_typeof(summary_bullets) = 'array'
       and jsonb_array_length(summary_bullets) > 0
    then summary_bullets
  when coalesce(trim(summary), '') <> ''
    then to_jsonb(array[trim(summary)])
  else '[]'::jsonb
end
where summary_bullets = '[]'::jsonb;

-- The user's approval covers cleanup of expired cloud insights according to the
-- existing session-retention policy. Keep still-valid insight results.
delete from public.insights
where expires_at is not null
  and expires_at < now();

-- Stop referring to session rows so AI insights can be fetched by the local
-- ProfessionalSession UUID without retaining the session/transcript in cloud.
alter table public.insights
  drop constraint if exists insights_session_id_fkey;

-- These RPCs exist only to manage cloud folders/sessions and are no longer used.
drop function if exists public.delete_professional_folder(uuid);
drop function if exists public.delete_professional_folder_and_sessions(uuid);

-- Drop the old transcript storage and the cloud copies of local Professional
-- Mode metadata. Dropping these tables deletes their rows but does not delete
-- auth.users, profiles, settings, or quick replies.
drop table if exists public.captions;
drop table if exists public.sessions;
drop table if exists public.folders;

commit;
