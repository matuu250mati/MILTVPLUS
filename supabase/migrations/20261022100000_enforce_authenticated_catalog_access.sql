-- Enforce the documented product requirement: catalog reads require an authenticated user.
-- The prior hardening migration accidentally restored anonymous access.
begin;

alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.content_submissions enable row level security;

-- Remove legacy policies: PostgreSQL ORs permissive policies together.
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
    execute format('drop policy %I on public.%I', existing_policy.policyname, existing_policy.tablename);
  end loop;
end;
$$;

-- Revoke anonymous SQL privileges as defense in depth.
revoke select on public.channels, public.movies, public.series, public.episodes from anon;
grant select on public.channels, public.movies, public.series, public.episodes to authenticated;

-- Table-level REVOKE does not remove column-level SELECT grants.
revoke select on table public.content_submissions from anon;
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

revoke insert, update, delete, truncate, references, trigger
  on public.channels, public.movies, public.series, public.episodes
  from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.content_submissions from anon, authenticated;
grant insert on public.content_submissions to authenticated;

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
  with check (auth.uid() = user_id and moderation_status = 'pending');

commit;
