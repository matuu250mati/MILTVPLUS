-- Harden catalog RLS without editing migrations already applied to QA.
-- PostgreSQL ORs permissive policies together, so remove legacy policies before
-- installing the single intended read/submit policy set.
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

-- Enforce row-level policies even when this migration is applied to a legacy
-- project whose tables were created without RLS enabled. Policies alone do not
-- restrict rows while RLS is disabled.
alter table public.channels enable row level security;
alter table public.movies enable row level security;
alter table public.series enable row level security;
alter table public.episodes enable row level security;
alter table public.content_submissions enable row level security;

revoke insert, update, delete, truncate, references, trigger
  on public.channels, public.movies, public.series, public.episodes
  from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.content_submissions from anon, authenticated;

grant select on public.channels, public.movies, public.series, public.episodes
  to anon, authenticated;

-- Do not expose submitter IDs or rights-confirmation fields through PostgREST.
-- `id` and `created_at` remain selectable because the catalog filters/orders on them.
revoke select on table public.content_submissions from anon, authenticated;
grant select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions to anon, authenticated;
grant insert on public.content_submissions to authenticated;

create policy "Authenticated users read published channels"
  on public.channels for select to anon, authenticated using (is_published);

create policy "Public users read published movies"
  on public.movies for select to anon, authenticated using (is_published);

create policy "Public users read published series"
  on public.series for select to anon, authenticated using (is_published);

create policy "Authenticated users read published episodes"
  on public.episodes for select to anon, authenticated
  using (
    is_published and exists (
      select 1 from public.series s
      where s.id = episodes.series_id and s.is_published
    )
  );

create policy "Public users read approved submissions"
  on public.content_submissions for select to anon, authenticated
  using (moderation_status = 'approved');

create policy "Users submit pending content"
  on public.content_submissions for insert to authenticated
  with check (auth.uid() = user_id and moderation_status = 'pending');
