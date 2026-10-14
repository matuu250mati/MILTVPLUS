-- Make published catalog entries readable before sign-in, matching app browsing UX.
-- This migration intentionally grants SELECT only; catalog writes remain server-side.
-- RLS policies below restrict SELECT to published rows.
grant select on public.channels, public.episodes to anon, authenticated;

 drop policy if exists "Authenticated users read published channels" on public.channels;
 drop policy if exists "Public users read published channels" on public.channels;
 create policy "Public users read published channels"
   on public.channels for select to anon, authenticated using (is_published);

 drop policy if exists "Authenticated users read published movies" on public.movies;
 drop policy if exists "Public users read published movies" on public.movies;
 create policy "Public users read published movies"
   on public.movies for select to anon, authenticated using (is_published);

 drop policy if exists "Authenticated users read published series" on public.series;
 drop policy if exists "Public users read published series" on public.series;
 create policy "Public users read published series"
   on public.series for select to anon, authenticated using (is_published);

 drop policy if exists "Authenticated users read published episodes" on public.episodes;
 drop policy if exists "Public users read published episodes" on public.episodes;
 create policy "Public users read published episodes"
   on public.episodes for select to anon, authenticated
   using (
     is_published and exists (
       select 1 from public.series s
       where s.id = episodes.series_id and s.is_published
     )
   );
