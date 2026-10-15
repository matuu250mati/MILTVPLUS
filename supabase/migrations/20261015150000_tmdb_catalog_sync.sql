-- Add TMDB identifiers so metadata syncs are idempotent.
-- Metadata-only movies are intentionally stored with an empty stream URL.
-- The client already prevents playback when no authorized stream is configured.
alter table public.movies
  add column if not exists tmdb_id bigint unique;

alter table public.series
  add column if not exists tmdb_id bigint unique;

create index if not exists movies_tmdb_id_idx on public.movies (tmdb_id);
create index if not exists series_tmdb_id_idx on public.series (tmdb_id);

comment on column public.movies.tmdb_id is
  'External TMDB movie ID used for safe metadata synchronization; nullable for manually managed records.';
comment on column public.series.tmdb_id is
  'External TMDB TV ID used for safe metadata synchronization; nullable for manually managed records.';
