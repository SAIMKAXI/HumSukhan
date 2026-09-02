begin;

alter table public.insights
  add column if not exists summary_bullets jsonb not null default '[]'::jsonb;

update public.insights
set summary_bullets = case
  when jsonb_typeof(summary_bullets) = 'array' and jsonb_array_length(summary_bullets) > 0 then summary_bullets
  when coalesce(trim(summary), '') <> '' then to_jsonb(array[trim(summary)])
  else '[]'::jsonb
end
where summary_bullets = '[]'::jsonb;

alter table public.insights
  drop column if exists vocabulary,
  drop column if exists themes;

alter table public.captions
  add column if not exists segments jsonb not null default '[]'::jsonb;

create or replace function public.delete_professional_folder(p_folder_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.sessions
     set folder_id = null
   where folder_id = p_folder_id
     and user_id = auth.uid();

  delete from public.folders
   where id = p_folder_id
     and user_id = auth.uid();
end;
$$;

revoke all on function public.delete_professional_folder(uuid) from public;
grant execute on function public.delete_professional_folder(uuid) to authenticated;

commit;
