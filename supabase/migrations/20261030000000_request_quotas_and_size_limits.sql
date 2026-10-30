-- Limits on how much any one caller can use the app's paid services and
-- store in the database.
--
-- The Edge Functions that call Deepgram, Soniox and Gemini are paid per
-- request. Before calling a provider, they ask use_request_quota() whether
-- the signed-in user still has requests left this minute and this day; the
-- check runs with the user's own token, so it also proves the caller is a
-- real, signed-in account (the public anon key that ships in the app is
-- refused). create-account has no user yet, so it uses use_signup_quota(),
-- which only the service role can call, counting by network address and in
-- total.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.request_counts (
  bucket text not null,
  window_start timestamptz not null,
  hits integer not null,
  primary key (bucket, window_start)
);
alter table private.request_counts enable row level security;
revoke all on private.request_counts from public, anon, authenticated;

-- Adds one hit to a bucket's current window and returns the new count.
create or replace function private.count_hit(p_bucket text, p_window_start timestamptz)
returns integer
language sql
security definer
set search_path = ''
as $$
  insert into private.request_counts as c (bucket, window_start, hits)
  values (p_bucket, p_window_start, 1)
  on conflict (bucket, window_start) do update set hits = c.hits + 1
  returning c.hits;
$$;
revoke all on function private.count_hit(text, timestamptz) from public, anon, authenticated;

-- Old windows are no longer read; drop them now and then.
create or replace function private.forget_old_counts()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.request_counts where window_start < now() - interval '2 days';
$$;
revoke all on function private.forget_old_counts() from public, anon, authenticated;

-- 'ok', 'limited', or 'signed_out' for the calling user and the named action.
-- The limits sit well above what the app sends in normal use (one
-- transcription per spoken phrase, one voice per reply).
create or replace function public.use_request_quota(action text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  per_minute integer;
  per_day integer;
  minute_hits integer;
  day_hits integer;
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return 'signed_out';
  end if;

  select l.per_minute, l.per_day into per_minute, per_day
  from (values
    ('transcribe', 60, 5000),
    ('speech', 60, 3000),
    ('insights', 10, 200),
    ('deepgram-token', 20, 300)
  ) as l(name, per_minute, per_day)
  where l.name = action;
  if per_minute is null then
    raise exception 'Unknown quota action: %', action using errcode = '22023';
  end if;

  minute_hits := private.count_hit(format('m:%s:%s', action, uid), date_trunc('minute', now()));
  day_hits := private.count_hit(format('d:%s:%s', action, uid), date_trunc('day', now()));
  if random() < 0.01 then
    perform private.forget_old_counts();
  end if;

  if minute_hits > per_minute or day_hits > per_day then
    return 'limited';
  end if;
  return 'ok';
end;
$$;
revoke all on function public.use_request_quota(text) from public, anon;
grant execute on function public.use_request_quota(text) to authenticated;

-- true while new accounts are allowed from this address, and in total.
create or replace function public.use_signup_quota(address text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  hour_start timestamptz := date_trunc('hour', now());
  address_hour integer;
  address_day integer;
  everyone_hour integer;
begin
  address_hour := private.count_hit(format('signup-h:%s', left(coalesce(address, 'unknown'), 64)), hour_start);
  address_day := private.count_hit(format('signup-d:%s', left(coalesce(address, 'unknown'), 64)), date_trunc('day', now()));
  everyone_hour := private.count_hit('signup-all', hour_start);
  return address_hour <= 5 and address_day <= 20 and everyone_hour <= 60;
end;
$$;
revoke all on function public.use_signup_quota(text) from public, anon, authenticated;
grant execute on function public.use_signup_quota(text) to service_role;

-- Size limits, far above what the app writes, so one account cannot fill
-- the database. Existing rows are well inside them.
alter table public.profiles
  add constraint profiles_name_length check (char_length(name) <= 100),
  add constraint profiles_avatar_emoji_length check (char_length(avatar_emoji) <= 16),
  add constraint profiles_avatar_data_length check (char_length(avatar_data) <= 2000000),
  add constraint profiles_preferred_language_length check (char_length(preferred_language) <= 32),
  add constraint profiles_tutor_name_length check (char_length(tutor_name) <= 100);

alter table public.quick_replies
  add constraint quick_replies_text_length check (char_length(text) <= 2000),
  add constraint quick_replies_category_length check (char_length(category) <= 64);

alter table public.settings
  add constraint settings_size check (octet_length(settings::text) <= 65536);

alter table public.insights
  add constraint insights_summary_length check (char_length(summary) <= 20000),
  add constraint insights_lists_size check (
    octet_length(coalesce(action_items, '[]'::jsonb)::text)
    + octet_length(coalesce(deadlines, '[]'::jsonb)::text)
    + octet_length(coalesce(mentioned_people, '[]'::jsonb)::text)
    + octet_length(coalesce(summary_bullets, '[]'::jsonb)::text) <= 200000
  );

commit;
