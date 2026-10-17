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

-- Existing M3U keys were globally unique by tvg-id/URL. Append the current
-- category to those keys before deploying the revised sync function. This
-- preserves each existing row and avoids deleting or merging catalog data.
update public.channels
set source_key = source_key || ':category:' ||
  regexp_replace(lower(trim(category)), '[^a-z0-9]+', '-', 'g')
where source_key like 'm3u:%'
  and source_key not like '%:category:%'
  and nullif(trim(category), '') is not null;

commit;
