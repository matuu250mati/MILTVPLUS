-- MILTVPLUS: diagnóstico de catálogo, solo lectura.
-- Ejecutar en Supabase SQL Editor. No inserta, actualiza ni elimina datos.
-- Permite distinguir entre filas ausentes, no publicadas y sin URL reproducible.

-- 1) Resumen por tabla: total, publicadas y filas con URL.
select
  'channels' as table_name,
  count(*) as total,
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true') as published,
  count(*) filter (
    where nullif(btrim(coalesce(
      to_jsonb(t)->>'url_stream',
      to_jsonb(t)->>'stream_url',
      to_jsonb(t)->>'m3u8_url',
      to_jsonb(t)->>'video_url',
      to_jsonb(t)->>'url',
      ''
    )), '') is not null
  ) as with_stream_url,
  count(*) filter (
    where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true'
      and nullif(btrim(coalesce(
        to_jsonb(t)->>'url_stream',
        to_jsonb(t)->>'stream_url',
        to_jsonb(t)->>'m3u8_url',
        to_jsonb(t)->>'video_url',
        to_jsonb(t)->>'url',
        ''
      )), '') is not null
  ) as published_with_stream_url
from public.channels t
union all
select
  'movies', count(*),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true'),
  count(*) filter (where nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true' and nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null)
from public.movies t
union all
select
  'series', count(*),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true'),
  count(*) filter (where nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true' and nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null)
from public.series t
union all
select
  'episodes', count(*),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true'),
  count(*) filter (where nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null),
  count(*) filter (where coalesce(to_jsonb(t)->>'is_published', 'false') = 'true' and nullif(btrim(coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')), '') is not null)
from public.episodes t
order by table_name;

-- 2) Categorías y cantidad de canales publicados.
select
  coalesce(to_jsonb(c)->>'category', to_jsonb(c)->>'genre', '(sin categoría)') as category,
  count(*) as channels
from public.channels c
where coalesce(to_jsonb(c)->>'is_published', 'false') = 'true'
group by 1
order by 1;

-- 3) Muestra de contenidos publicados que no tienen URL de reproducción.
-- Metadatos sin stream no deben tratarse como reproducibles.
select *
from (
  select
    'movies' as table_name,
    coalesce(to_jsonb(t)->>'id', '') as id,
    coalesce(to_jsonb(t)->>'title', to_jsonb(t)->>'name', '(sin título)') as title,
    coalesce(to_jsonb(t)->>'category', to_jsonb(t)->>'genre', '') as category,
    coalesce(to_jsonb(t)->>'is_published', 'false') as is_published,
    coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '') as stream_url
  from public.movies t
  union all
  select
    'series',
    coalesce(to_jsonb(t)->>'id', ''),
    coalesce(to_jsonb(t)->>'title', to_jsonb(t)->>'name', '(sin título)'),
    coalesce(to_jsonb(t)->>'category', to_jsonb(t)->>'genre', ''),
    coalesce(to_jsonb(t)->>'is_published', 'false'),
    coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')
  from public.series t
  union all
  select
    'episodes',
    coalesce(to_jsonb(t)->>'id', ''),
    coalesce(to_jsonb(t)->>'title', to_jsonb(t)->>'name', '(sin título)'),
    coalesce(to_jsonb(t)->>'category', to_jsonb(t)->>'genre', ''),
    coalesce(to_jsonb(t)->>'is_published', 'false'),
    coalesce(to_jsonb(t)->>'url_stream', to_jsonb(t)->>'stream_url', to_jsonb(t)->>'m3u8_url', to_jsonb(t)->>'video_url', to_jsonb(t)->>'url', '')
  from public.episodes t
) catalog
where is_published = 'true' and nullif(btrim(stream_url), '') is null
order by table_name, title
limit 200;
