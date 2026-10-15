-- Add ordered playback mirrors for authorized VOD sources.
-- Existing single stream URLs are preserved as the first candidate.
alter table public.movies
  add column if not exists stream_urls jsonb not null default '[]'::jsonb;

alter table public.episodes
  add column if not exists stream_urls jsonb not null default '[]'::jsonb;

update public.movies
set stream_urls = jsonb_build_array(url_stream)
where (stream_urls is null or stream_urls = '[]'::jsonb)
  and url_stream is not null
  and btrim(url_stream) <> '';

update public.episodes
set stream_urls = jsonb_build_array(url_stream)
where (stream_urls is null or stream_urls = '[]'::jsonb)
  and url_stream is not null
  and btrim(url_stream) <> '';

alter table public.movies
  drop constraint if exists movies_stream_urls_array_check;
alter table public.movies
  add constraint movies_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

alter table public.episodes
  drop constraint if exists episodes_stream_urls_array_check;
alter table public.episodes
  add constraint episodes_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

comment on column public.movies.stream_urls is
  'Ordered HTTPS playback URLs for authorized mirrors; the app tries them in order.';
comment on column public.episodes.stream_urls is
  'Ordered HTTPS playback URLs for authorized mirrors; the app tries them in order.';
