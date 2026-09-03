begin;

create or replace function public.delete_professional_folder_and_sessions(p_folder_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  session_ids uuid[];
begin
  select coalesce(array_agg(id), '{}')
    into session_ids
    from public.sessions
   where folder_id = p_folder_id
     and user_id = auth.uid();

  if coalesce(array_length(session_ids, 1), 0) > 0 then
    delete from public.captions
     where session_id = any(session_ids)
       and user_id = auth.uid();

    delete from public.insights
     where session_id = any(session_ids)
       and user_id = auth.uid();

    delete from public.sessions
     where id = any(session_ids)
       and user_id = auth.uid();
  end if;

  delete from public.folders
   where id = p_folder_id
     and user_id = auth.uid();
end;
$$;

revoke all on function public.delete_professional_folder_and_sessions(uuid) from public;
grant execute on function public.delete_professional_folder_and_sessions(uuid) to authenticated;

commit;
