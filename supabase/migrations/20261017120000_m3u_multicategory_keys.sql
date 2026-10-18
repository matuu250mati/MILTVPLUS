-- MILTVPLUS QA: namespace imported channel keys by category to preserve multi-list membership.
-- This migration is intentionally prepared only; it has not been applied to any Supabase project.
begin;

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; inspect the target schema before applying this migration.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'channels' and column_name = 'source_key'
  ) then
    raise exception 'public.channels.source_key is missing; apply the catalog sync migration first.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'channels' and column_name = 'category'
  ) then
    raise exception 'public.channels.category is missing; inspect the target schema before applying this migration.';
  end if;
end $$;

-- Preflight the unique index before rewriting keys. Abort the whole transaction
-- rather than risk overwriting or merging a row if a target key already exists.
do $
begin
  if exists (
    select 1
    from public.channels c
    join public.channels existing
      on existing.source_key =
        c.source_key || ':category:' ||
        regexp_replace(
          lower(coalesce(nullif(trim(c.category), ''), 'TV en Vivo')),
          '[^a-z0-9]+', '-', 'g'
        )
      and existing.id <> c.id
    where c.source_key like 'm3u:%'
      and c.source_key not like '%:category:%'
  ) then
    raise exception 'M3U category-key migration would collide with an existing source_key. No rows were changed; inspect duplicate keys first.';
  end if;
end $;

-- Existing M3U keys were globally unique by tvg-id/URL. Append the normalized
-- category slug before deploying the revised sync function. Rows with a blank
-- category use the explicit neutral category to avoid leaving legacy global keys.
update public.channels
set source_key = source_key || ':category:' ||
  regexp_replace(
    lower(coalesce(nullif(trim(category), ''), 'TV en Vivo')),
    '[^a-z0-9]+', '-', 'g'
  )
where source_key like 'm3u:%'
  and source_key not like '%:category:%';

commit;
