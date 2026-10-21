-- Catalog sync requires stable TMDB identifiers; nullable values preserve manually
-- curated rows while unique indexes prevent duplicate imported metadata.
alter table public.movies
  add column if not exists tmdb_id bigint;

alter table public.series
  add column if not exists tmdb_id bigint;

create unique index if not exists movies_tmdb_id_unique_idx
  on public.movies (tmdb_id);

create unique index if not exists series_tmdb_id_unique_idx
  on public.series (tmdb_id);

-- Community submissions are moderated server-side before they enter the public
-- catalog. Existing installs are upgraded with additive columns only.
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

alter table public.content_submissions enable row level security;
grant select on public.content_submissions to anon, authenticated;
grant insert on public.content_submissions to authenticated;

drop policy if exists "Public users read approved submissions" on public.content_submissions;
create policy "Public users read approved submissions"
  on public.content_submissions for select to anon, authenticated
  using (moderation_status = 'approved');

drop policy if exists "Users submit pending content" on public.content_submissions;
create policy "Users submit pending content"
  on public.content_submissions for insert to authenticated
  with check (
    auth.uid() = user_id
    and moderation_status = 'pending'
  );
