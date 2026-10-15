-- MILTVPLUS: canonical genre taxonomy for published live-channel filtering.
-- Safe with schema variants: channel names are read through to_jsonb so this
-- migration does not assume whether the deployment uses title, name, or aliases.
begin;

do $migration$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; refusing to normalize categories.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'channels'
      and column_name = 'category'
  ) then
    raise exception 'public.channels.category does not exist; refusing to normalize categories.';
  end if;
end
$migration$;

-- Precedence matters: sports and news channels retain their genre even when
-- they are produced in Argentina or contain country metadata.
update public.channels c
set category = 'Deportes'
where lower(concat_ws(' ',
  to_jsonb(c)->>'title', to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name', to_jsonb(c)->>'channel_title',
  to_jsonb(c)->>'category'
)) ~ '(espn|tyc[[:space:]]*sports|fox[[:space:]]*sports|tnt[[:space:]]*sports|dsports|d[[:space:]]*sports|directv[[:space:]]*sports|deportv|eurosport|sportv|nba[[:space:]]*tv|nfl[[:space:]]*network|formula[[:space:]]*1|f1[[:space:]]|bein[[:space:]]*sports|deportes|deportivo|sports tv)';

update public.channels c
set category = 'Noticias'
where lower(concat_ws(' ',
  to_jsonb(c)->>'title', to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name', to_jsonb(c)->>'channel_title',
  to_jsonb(c)->>'category'
)) ~ '(noticias|noticiero|news([[:space:]]|$)|informativo|c5n|todo[[:space:]]*noticias|canal[[:space:]]*26|a24|cronica|crónica|cnn|bbc[[:space:]]*news|france[[:space:]]*24|dw[[:space:]]*news|euronews)'
and lower(coalesce(c.category, '')) <> 'deportes';

update public.channels c
set category = 'Cultura/Documentales'
where lower(concat_ws(' ',
  to_jsonb(c)->>'title', to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name', to_jsonb(c)->>'channel_title',
  to_jsonb(c)->>'category'
)) ~ '(documental|documentary|discovery|national[[:space:]]*geographic|nat[[:space:]]*geo|history[[:space:]]*channel|animal[[:space:]]*planet|encuentro|pakapaka|cultura|cultural|educacion|educación|arte[[:space:]]*tv)'
and lower(coalesce(c.category, '')) not in ('deportes', 'noticias');

update public.channels c
set category = 'HBO/Cine'
where lower(concat_ws(' ',
  to_jsonb(c)->>'title', to_jsonb(c)->>'name',
  to_jsonb(c)->>'channel_name', to_jsonb(c)->>'channel_title',
  to_jsonb(c)->>'category'
)) ~ '(^|[[:space:]])(hbo|cinemax|tcm|space|studio[[:space:]]*universal|universal[[:space:]]*cinema|cinecanal|amc|golden|paramount[[:space:]]*network|star[[:space:]]*channel)([[:space:]]|$)'
and lower(coalesce(c.category, '')) not in ('deportes', 'noticias', 'cultura/documentales');

update public.channels c
set category = 'TV Argentina'
where (
  lower(concat_ws(' ',
    to_jsonb(c)->>'title', to_jsonb(c)->>'name',
    to_jsonb(c)->>'channel_name', to_jsonb(c)->>'channel_title'
  )) ~ '(telefe|el[[:space:]]*trece|eltrece|america[[:space:]]*tv|américa[[:space:]]*tv|tv[[:space:]]*publica|tv[[:space:]]*pública|canal[[:space:]]*9|net[[:space:]]*tv|ln[[:space:]]*\+|la[[:space:]]*nacion)'
  or lower(coalesce(to_jsonb(c)->>'country_code', '')) in ('ar', 'argentina')
  or lower(coalesce(c.category, '')) in ('argentina', 'tv argentina general', 'tv en vivo')
)
and lower(coalesce(c.category, '')) not in
  ('deportes', 'noticias', 'cultura/documentales', 'hbo/cine');

create index if not exists channels_published_category_order_idx
  on public.channels (is_published, category, sort_order);

commit;

-- Verify after deployment:
-- select category, count(*) from public.channels group by category order by category;
-- Review ambiguous or unknown rows before assigning them a category manually.
