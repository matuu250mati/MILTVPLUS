-- Keep the movie schema aligned with MovieModel and the TMDB sync function.
-- Existing single-stream records remain playable; new rows get an empty mirror list.
alter table public.movies
  add column if not exists stream_urls jsonb not null default '[]'::jsonb;

alter table public.movies
  drop constraint if exists movies_stream_urls_array_check;

alter table public.movies
  add constraint movies_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

update public.movies
set stream_urls = jsonb_build_array(url_stream)
where coalesce(trim(url_stream), '') <> ''
  and stream_urls = '[]'::jsonb;
