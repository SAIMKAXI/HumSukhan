begin;

alter table public.insights
  add constraint insights_summary_bullets_array_check
  check (jsonb_typeof(summary_bullets) = 'array');

commit;
