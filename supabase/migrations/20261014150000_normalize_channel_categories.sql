-- MILTVPLUS: normalize known live-channel categories without deleting rows or changing stream URLs.
-- Apply after 20261014090000_channels_compatibility.sql in Supabase SQL Editor.
-- Review the matching channel names with the preview query in supabase/SETUP_ES.md before applying this migration.

begin;

do $migration$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; no category changes were applied.';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'channels'
      and column_name = 'category'
  ) then
    raise exception 'public.channels.category does not exist; inspect the live schema before applying this migration.';
  end if;
end
$migration$;

-- Sports takes priority so Argentine sports broadcasters remain in Deportes.
update public.channels as c
set category = 'Deportes'
where lower(coalesce(
  to_jsonb(c)->>'title',
  to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name',
  to_jsonb(c)->>'channel_title',
  ''
)) ~ '(espn|tyc[[:space:]]*sports|fox[[:space:]]*sports|tnt[[:space:]]*sports|d[[:space:]]*sports|dsports|directv[[:space:]]*sports|deportv|eurosport|sportv|nba[[:space:]]*tv|nfl[[:space:]]*network|formula[[:space:]]*1|f1[[:space:]]|golf[[:space:]]*channel|bein[[:space:]]*sports)'
and category is distinct from 'Deportes';

-- Match only recognizable Argentine broadcaster names; unknown rows are untouched.
update public.channels as c
set category = 'TV Argentina'
where (
  lower(coalesce(
    to_jsonb(c)->>'title',
    to_jsonb(c)->>'name',
    to_jsonb(c)->>'channel_name',
    to_jsonb(c)->>'channel_title',
    ''
  )) ~ '(telefe|el[[:space:]]*trece|eltrece|america[[:space:]]*tv|américa[[:space:]]*tv|tv[[:space:]]*publica|tv[[:space:]]*pública|canal[[:space:]]*9|c5n|todo[[:space:]]*noticias|\mtn\M|cronica|crónica|a24|canal[[:space:]]*26|net[[:space:]]*tv|ln[[:space:]]*\+|la[[:space:]]*nacion[[:space:]]*\+)'
  or lower(coalesce(to_jsonb(c)->>'country_code', '')) in ('ar', 'argentina')
  or lower(coalesce(to_jsonb(c)->>'category', '')) in ('argentina', 'tv en vivo', 'tv argentina')
)
and lower(coalesce(
  to_jsonb(c)->>'title',
  to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name',
  to_jsonb(c)->>'channel_title',
  ''
)) !~ '(espn|tyc[[:space:]]*sports|fox[[:space:]]*sports|tnt[[:space:]]*sports|d[[:space:]]*sports|dsports|directv[[:space:]]*sports|deportv|eurosport|sportv|nba[[:space:]]*tv|nfl[[:space:]]*network|formula[[:space:]]*1|f1[[:space:]]|golf[[:space:]]*channel|bein[[:space:]]*sports)'
and lower(coalesce(to_jsonb(c)->>'category', '')) not in ('deportes', 'deportivo')
and category is distinct from 'TV Argentina';

create index if not exists channels_published_category_order_idx
  on public.channels (is_published, category, sort_order);

commit;

-- Verification after commit:
-- select category, count(*) from public.channels group by category order by category;
-- select title, category, is_published from public.channels
-- where category in ('Deportes', 'Deportivo', 'TV Argentina')
-- order by category, title;
