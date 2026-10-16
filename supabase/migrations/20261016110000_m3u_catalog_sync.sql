-- MILTVPLUS: support repeatable, source-tracked M3U channel imports.
-- Safe/non-destructive: adds nullable source metadata and leaves existing catalog rows intact.
begin;

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; inspect the live schema before applying this migration.';
  end if;
end $$;

alter table public.channels add column if not exists source_key text;
alter table public.channels add column if not exists source_name text;
alter table public.channels add column if not exists group_title text;
alter table public.channels add column if not exists country_code text;

-- Multiple legacy rows may have NULL source_key; PostgreSQL allows those under a normal unique index.
create unique index if not exists channels_source_key_uidx
  on public.channels (source_key);

comment on column public.channels.source_key is
  'Stable key for rows managed by the approved M3U catalog sync; NULL for manually managed legacy rows.';
comment on column public.channels.source_name is
  'Configured playlist source that supplied this live channel.';
comment on column public.channels.group_title is
  'M3U group-title metadata or the configured source category when absent.';

commit;
