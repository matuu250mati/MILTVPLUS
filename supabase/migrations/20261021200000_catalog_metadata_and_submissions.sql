-- Idempotently align existing QA databases with the catalog models and TMDB sync.
-- This migration is additive; it does not publish imported metadata or invent streams.
create extension if not exists pgcrypto;

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Canal sin título',
  synopsis text not null default '',
  category text not null default 'Argentina',
  logo text,
  url_stream text not null default '',
  stream_urls jsonb not null default '[]'::jsonb,
  stream_format text not null default 'hls',
  country_code text not null default 'AR',
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  tmdb_id bigint unique,
  title text not null default 'Sin título',
  synopsis text not null default '',
  category text not null default 'Películas',
  genres text[] not null default '{}',
  logo text,
  backdrop_url text,
  url_stream text not null default '',
  stream_urls jsonb not null default '[]'::jsonb,
  release_year integer,
  duration_seconds integer,
  country_code text not null default 'AR',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.series (
  id uuid primary key default gen_random_uuid(),
  tmdb_id bigint unique,
  title text not null default 'Sin título',
  synopsis text not null default '',
  category text not null default 'Series',
  genres text[] not null default '{}',
  logo text,
  backdrop_url text,
  release_year integer,
  country_code text not null default 'AR',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.episodes (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  title text not null,
  synopsis text not null default '',
  season_number integer not null default 1 check (season_number > 0),
  episode_number integer not null default 1 check (episode_number > 0),
  logo text,
  url_stream text not null default '',
  duration_seconds integer,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  unique (series_id, season_number, episode_number)
);

-- Fill in missing columns on databases whose tables were created manually from
-- older versions of schema.sql. Defaults preserve existing rows.
alter table public.channels
  add column if not exists title text not null default 'Canal sin título',
  add column if not exists synopsis text not null default '',
  add column if not exists category text not null default 'Argentina',
  add column if not exists logo text,
  add column if not exists url_stream text not null default '',
  add column if not exists stream_urls jsonb not null default '[]'::jsonb,
  add column if not exists stream_format text not null default 'hls',
  add column if not exists country_code text not null default 'AR',
  add column if not exists sort_order integer not null default 0,
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.movies
  add column if not exists tmdb_id bigint,
  add column if not exists title text not null default 'Sin título',
  add column if not exists synopsis text not null default '',
  add column if not exists category text not null default 'Películas',
  add column if not exists genres text[] not null default '{}',
  add column if not exists logo text,
  add column if not exists backdrop_url text,
  add column if not exists url_stream text not null default '',
  add column if not exists stream_urls jsonb not null default '[]'::jsonb,
  add column if not exists release_year integer,
  add column if not exists duration_seconds integer,
  add column if not exists country_code text not null default 'AR',
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.series
  add column if not exists tmdb_id bigint,
  add column if not exists title text not null default 'Sin título',
  add column if not exists synopsis text not null default '',
  add column if not exists category text not null default 'Series',
  add column if not exists genres text[] not null default '{}',
  add column if not exists logo text,
  add column if not exists backdrop_url text,
  add column if not exists release_year integer,
  add column if not exists country_code text not null default 'AR',
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.episodes
  add column if not exists series_id uuid references public.series(id) on delete cascade,
  add column if not exists title text not null default 'Episodio',
  add column if not exists synopsis text not null default '',
  add column if not exists season_number integer not null default 1,
  add column if not exists episode_number integer not null default 1,
  add column if not exists logo text,
  add column if not exists url_stream text not null default '',
  add column if not exists duration_seconds integer,
  add column if not exists is_published boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

-- Nullable TMDB IDs let manually curated rows coexist with imported rows.
create unique index if not exists movies_tmdb_id_unique_idx on public.movies (tmdb_id);
create unique index if not exists series_tmdb_id_unique_idx on public.series (tmdb_id);
create index if not exists channels_published_order_idx on public.channels (is_published, sort_order, title);
create index if not exists movies_published_idx on public.movies (is_published, release_year desc);
create index if not exists series_published_idx on public.series (is_published, title);
create index if not exists episodes_series_order_idx on public.episodes (series_id, season_number, episode_number);

alter table public.movies drop constraint if exists movies_stream_urls_array_check;
alter table public.movies add constraint movies_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');
alter table public.channels drop constraint if exists channels_stream_urls_array_check;
alter table public.channels add constraint channels_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

-- Moderated community catalog. Client users can submit pending items but cannot
-- approve, update, or delete submissions. Approval remains an admin/server action.
create table if not exists public.content_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  title text not null,
  description text not null default '',
  stream_url text not null,
  poster_url text,
  duration_seconds integer,
  series_title text,
  season_number integer,
  episode_number integer,
  media_type text not null check (media_type in ('movie', 'episode')),
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.content_submissions
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists title text,
  add column if not exists description text not null default '',
  add column if not exists stream_url text,
  add column if not exists poster_url text,
  add column if not exists duration_seconds integer,
  add column if not exists series_title text,
  add column if not exists season_number integer,
  add column if not exists episode_number integer,
  add column if not exists media_type text,
  add column if not exists moderation_status text not null default 'pending',
  add column if not exists created_at timestamptz not null default now();

create index if not exists content_submissions_moderation_type_created_idx
  on public.content_submissions (moderation_status, media_type, created_at desc);

alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.content_submissions enable row level security;

grant select on public.channels, public.movies, public.series, public.episodes,
  public.content_submissions to anon, authenticated;
grant insert on public.content_submissions to authenticated;

drop policy if exists "Authenticated users read published channels" on public.channels;
create policy "Authenticated users read published channels"
  on public.channels for select to anon, authenticated using (is_published);

drop policy if exists "Public users read published movies" on public.movies;
create policy "Public users read published movies"
  on public.movies for select to anon, authenticated using (is_published);

drop policy if exists "Public users read published series" on public.series;
create policy "Public users read published series"
  on public.series for select to anon, authenticated using (is_published);

drop policy if exists "Authenticated users read published episodes" on public.episodes;
create policy "Authenticated users read published episodes"
  on public.episodes for select to anon, authenticated
  using (
    is_published and exists (
      select 1 from public.series s
      where s.id = episodes.series_id and s.is_published
    )
  );

drop policy if exists "Public users read approved submissions" on public.content_submissions;
create policy "Public users read approved submissions"
  on public.content_submissions for select to anon, authenticated
  using (moderation_status = 'approved');

drop policy if exists "Users submit pending content" on public.content_submissions;
create policy "Users submit pending content"
  on public.content_submissions for insert to authenticated
  with check (auth.uid() = user_id and moderation_status = 'pending');
