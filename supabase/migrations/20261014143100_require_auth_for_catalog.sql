-- Enforce the product requirement: only signed-in users can read the catalog.
-- Keep SELECT grants separate from RLS; anon may query the API but receives no rows.
begin;

drop policy if exists "Public users read published channels" on public.channels;
drop policy if exists "Authenticated users read published channels" on public.channels;
create policy "Authenticated users read published channels"
  on public.channels for select to authenticated
  using (is_published);

drop policy if exists "Public users read published movies" on public.movies;
drop policy if exists "Authenticated users read published movies" on public.movies;
create policy "Authenticated users read published movies"
  on public.movies for select to authenticated
  using (is_published);

drop policy if exists "Public users read published series" on public.series;
drop policy if exists "Authenticated users read published series" on public.series;
create policy "Authenticated users read published series"
  on public.series for select to authenticated
  using (is_published);

drop policy if exists "Public users read published episodes" on public.episodes;
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
create policy "Authenticated users read approved submissions"
  on public.content_submissions for select to authenticated
  using (moderation_status = 'approved');

commit;
