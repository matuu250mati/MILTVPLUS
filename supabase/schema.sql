-- MILTV PLUS catalog schema. Run in Supabase SQL Editor.
-- Only authenticated users can read published catalog entries.
create extension if not exists pgcrypto;

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  synopsis text not null default '',
  category text not null default 'Argentina',
  logo text,
  url_stream text not null,
  stream_format text not null default 'hls' check (stream_format in ('hls', 'm3u8')),
  country_code text not null default 'AR',
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  synopsis text not null default '',
  category text not null default 'Películas',
  genres text[] not null default '{}',
  logo text,
  backdrop_url text,
  url_stream text not null,
  release_year integer,
  duration_seconds integer,
  country_code text not null default 'AR',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.series (
  id uuid primary key default gen_random_uuid(),
  title text not null,
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
  url_stream text not null,
  duration_seconds integer,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  unique (series_id, season_number, episode_number)
);

create index if not exists channels_published_order_idx
  on public.channels (is_published, sort_order, title);
create index if not exists movies_published_idx
  on public.movies (is_published, release_year desc);
create index if not exists series_published_idx
  on public.series (is_published, title);
create index if not exists episodes_series_order_idx
  on public.episodes (series_id, season_number, episode_number);

alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;

drop policy if exists "Authenticated users read published channels" on public.channels;
create policy "Authenticated users read published channels"
  on public.channels for select to authenticated using (is_published);

drop policy if exists "Authenticated users read published movies" on public.movies;
create policy "Authenticated users read published movies"
  on public.movies for select to authenticated using (is_published);

drop policy if exists "Authenticated users read published series" on public.series;
create policy "Authenticated users read published series"
  on public.series for select to authenticated using (is_published);

drop policy if exists "Authenticated users read published episodes" on public.episodes;
create policy "Authenticated users read published episodes"
  on public.episodes for select to authenticated
  using (
    is_published and exists (
      select 1 from public.series s
      where s.id = episodes.series_id and s.is_published
    )
  );

-- No client-side INSERT/UPDATE/DELETE policies are intentionally created.
-- Manage catalog writes from the Supabase dashboard or a trusted server using
-- the service_role key; never ship that key in the Flutter app.
