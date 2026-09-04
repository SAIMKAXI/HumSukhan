begin;

-- Keep the newest generated insight for any legacy session duplicates before
-- adding the uniqueness guarantee. This is intentionally data-preserving.
with ranked as (
  select
    ctid,
    row_number() over (
      partition by session_id
      order by generated_at desc nulls last, id desc
    ) as rn
  from public.insights
  where session_id is not null
)
delete from public.insights i
using ranked r
where i.ctid = r.ctid
  and r.rn > 1;

create unique index if not exists insights_session_id_unique_idx
  on public.insights (session_id);

commit;
