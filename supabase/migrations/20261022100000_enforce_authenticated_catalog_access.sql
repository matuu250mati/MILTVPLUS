-- Enforce authenticated-only catalog reads without removing owner/moderator workflows.
-- PostgreSQL ORs permissive policies together; replace only catalog-read policies
-- and explicitly restore the privileged policies that an older hardening migration
-- may have removed. Never drop every policy on these tables.
begin;

-- Fresh schema.sql installs may predate the community rights-confirmation column.
-- Add it before creating the insert policy that references it.
alter table public.content_submissions
  add column if not exists rights_confirmed boolean not null default false;

alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.content_submissions enable row level security;

-- Remove only known legacy catalog-read policies. Preserve unrelated policies.
drop policy if exists "Public users read published channels" on public.channels;
drop policy if exists "Authenticated users read published channels" on public.channels;
drop policy if exists "Public users read published movies" on public.movies;
drop policy if exists "Authenticated users read published movies" on public.movies;
drop policy if exists "Public users read published series" on public.series;
drop policy if exists "Authenticated users read published series" on public.series;
drop policy if exists "Public users read published episodes" on public.episodes;
drop policy if exists "Authenticated users read published episodes" on public.episodes;
drop policy if exists "Public users read approved submissions" on public.content_submissions;
drop policy if exists "Authenticated users read approved submissions" on public.content_submissions;
drop policy if exists "Submit own pending content" on public.content_submissions;
drop policy if exists "Users submit own pending content" on public.content_submissions;
drop policy if exists "Users submit pending content" on public.content_submissions;
drop policy if exists "Read own submissions" on public.content_submissions;
drop policy if exists "Moderators read submissions" on public.content_submissions;
drop policy if exists "Moderators review submissions" on public.content_submissions;

-- Anonymous clients cannot read catalog tables. Keep authenticated grants on
-- movies/series/episodes for the owner-only RLS policies below.
revoke select, insert, update, delete, truncate, references, trigger
  on public.channels, public.movies, public.series, public.episodes from anon;
grant select on public.channels, public.movies, public.series, public.episodes to authenticated;

-- The preceding historical migration revoked client write privileges. Restore
-- them only for authenticated owner-managed movie/series/episode publishing;
-- RLS policies below remain the row-level authorization boundary.
grant insert, update, delete on public.movies, public.series, public.episodes
  to authenticated;

-- Column grants survive table-level revokes, so remove anon access explicitly.
revoke select on table public.content_submissions from anon, authenticated;
revoke select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions from anon, authenticated;
grant select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions to authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.content_submissions from anon, authenticated;
grant insert on public.content_submissions to authenticated;
grant update (moderation_status) on public.content_submissions to authenticated;

create policy "Authenticated users read published channels"
  on public.channels for select to authenticated using (is_published);
create policy "Authenticated users read published movies"
  on public.movies for select to authenticated using (is_published);
create policy "Authenticated users read published series"
  on public.series for select to authenticated using (is_published);
create policy "Authenticated users read published episodes"
  on public.episodes for select to authenticated
  using (
    is_published and exists (
      select 1 from public.series s
      where s.id = episodes.series_id and s.is_published
    )
  );
create policy "Authenticated users read approved submissions"
  on public.content_submissions for select to authenticated
  using (moderation_status = 'approved');

create policy "Users submit pending content"
  on public.content_submissions for insert to authenticated
  with check (
    auth.uid() = user_id
    and rights_confirmed
    and moderation_status = 'pending'
  );

-- Users can inspect their own submissions; moderators can inspect pending rows.
create policy "Read own submissions"
  on public.content_submissions for select to authenticated
  using (auth.uid() = user_id);
create policy "Moderators read submissions"
  on public.content_submissions for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'));

create policy "Moderators review submissions"
  on public.content_submissions for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'))
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator')
    and moderation_status in ('approved', 'rejected')
  );

-- Restore owner-only CRUD policies because the previous broad hardening migration
-- removed all policies on these tables. Table grants alone do not authorize rows.
create policy "MILTVPLUS owner reads all movies"
  on public.movies for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner inserts movies"
  on public.movies for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner updates movies"
  on public.movies for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner deletes movies"
  on public.movies for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

create policy "MILTVPLUS owner reads all series"
  on public.series for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner inserts series"
  on public.series for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner updates series"
  on public.series for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner deletes series"
  on public.series for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

create policy "MILTVPLUS owner reads all episodes"
  on public.episodes for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner inserts episodes"
  on public.episodes for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner updates episodes"
  on public.episodes for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');
create policy "MILTVPLUS owner deletes episodes"
  on public.episodes for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

commit;
