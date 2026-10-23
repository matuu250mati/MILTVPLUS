-- MILTV PLUS catalog schema. Run in Supabase SQL Editor for a new project.
-- Catalog reads require authenticated sessions; row-level policies control owner/moderator actions.
create extension if not exists pgcrypto;

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  synopsis text not null default '',
  category text not null default 'Argentina',
  logo text,
  url_stream text not null,
  stream_urls jsonb not null default '[]'::jsonb check (jsonb_typeof(stream_urls) = 'array'),
  stream_format text not null default 'hls' check (stream_format in ('hls', 'm3u8')),
  country_code text not null default 'AR',
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  tmdb_id bigint,
  title text not null,
  synopsis text not null default '',
  category text not null default 'Películas',
  genres text[] not null default '{}',
  logo text,
  backdrop_url text,
  url_stream text not null,
  stream_urls jsonb not null default '[]'::jsonb check (jsonb_typeof(stream_urls) = 'array'),
  release_year integer,
  duration_seconds integer,
  country_code text not null default 'AR',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.series (
  id uuid primary key default gen_random_uuid(),
  tmdb_id bigint,
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
  rights_confirmed boolean not null default false,
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  constraint content_submission_rights check (rights_confirmed)
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
create unique index if not exists movies_tmdb_id_unique_idx
  on public.movies (tmdb_id);
create index if not exists series_published_idx
  on public.series (is_published, title);
create unique index if not exists series_tmdb_id_unique_idx
  on public.series (tmdb_id);
create index if not exists content_submissions_moderation_type_created_idx
  on public.content_submissions (moderation_status, media_type, created_at desc);
create index if not exists episodes_series_order_idx
  on public.episodes (series_id, season_number, episode_number);

alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.content_submissions enable row level security;

-- SQL privileges are required in addition to RLS policies.
-- Client roles may read published catalog rows, but cannot write catalog data.
revoke insert, update, delete, truncate, references, trigger
  on public.channels, public.movies, public.series, public.episodes
  from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.content_submissions from anon, authenticated;

revoke select on public.channels, public.movies, public.series, public.episodes
  from anon;
grant select on public.channels, public.movies, public.series, public.episodes
  to authenticated;

-- Only grant public catalog fields; keep submitter identity and rights metadata private.
revoke select on table public.content_submissions from anon, authenticated;
revoke select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions from anon;
grant select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions to authenticated;
grant insert on public.content_submissions to authenticated;

do $$
declare
  existing_policy record;
begin
  for existing_policy in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('channels', 'movies', 'series', 'episodes', 'content_submissions')
  loop
    execute format(
      'drop policy %I on public.%I',
      existing_policy.policyname,
      existing_policy.tablename
    );
  end loop;
end;
$$;

drop policy if exists "Authenticated users read published channels" on public.channels;
create policy "Authenticated users read published channels"
  on public.channels for select to authenticated using (is_published);

drop policy if exists "Authenticated users read published movies" on public.movies;
drop policy if exists "Public users read published movies" on public.movies;
drop policy if exists "Authenticated users read published movies" on public.movies;
create policy "Authenticated users read published movies"
  on public.movies for select to authenticated using (is_published);

drop policy if exists "Authenticated users read published series" on public.series;
drop policy if exists "Public users read published series" on public.series;
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

drop policy if exists "Public users read approved submissions" on public.content_submissions;
drop policy if exists "Authenticated users read approved submissions" on public.content_submissions;
create policy "Authenticated users read approved submissions"
  on public.content_submissions for select to authenticated
  using (moderation_status = 'approved');

drop policy if exists "Users submit pending content" on public.content_submissions;
create policy "Users submit pending content"
  on public.content_submissions for insert to authenticated
  with check (
    auth.uid() = user_id
    and rights_confirmed
    and moderation_status = 'pending'
  );

-- No client-side INSERT/UPDATE/DELETE policies are intentionally created.
-- Manage catalog writes from the Supabase dashboard or a trusted server using
-- the service_role key; never ship that key in the Flutter app.
