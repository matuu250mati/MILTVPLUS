-- MILTVPLUS QA: safe, repeatable M3U channel imports.
-- Adds source tracking only; does not delete or rewrite existing manual rows.
begin;

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; inspect the QA schema before applying this migration.';
  end if;
end $$;

alter table public.channels add column if not exists source_key text;
alter table public.channels add column if not exists source_name text;
alter table public.channels add column if not exists group_title text;
alter table public.channels add column if not exists country_code text;

create unique index if not exists channels_source_key_uidx
  on public.channels (source_key);

comment on column public.channels.source_key is
  'Stable source identity plus category membership for rows managed by the M3U sync; NULL for manual legacy rows.';
comment on column public.channels.source_name is
  'Configured playlist source that supplied this live channel.';
comment on column public.channels.group_title is
  'M3U group-title metadata or the configured source category when absent.';

commit;
