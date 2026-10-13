-- Make published VOD metadata available to the app before sign-in.
-- This grants SELECT only; client-side writes remain denied by RLS.
-- Stream URLs must be limited to content the catalog owner is authorized to publish.

drop policy if exists "Authenticated users read published movies" on public.movies;
drop policy if exists "Public users read published movies" on public.movies;
create policy "Public users read published movies"
  on public.movies
  for select
  to anon, authenticated
  using (is_published);

drop policy if exists "Authenticated users read published series" on public.series;
drop policy if exists "Public users read published series" on public.series;
create policy "Public users read published series"
  on public.series
  for select
  to anon, authenticated
  using (is_published);
