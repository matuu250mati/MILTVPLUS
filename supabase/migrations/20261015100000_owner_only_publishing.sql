-- Owner-only publishing and public delivery for MILTVPLUS.
-- Assign app_metadata.role = 'owner' to exactly one trusted Supabase Auth user
-- from the Supabase dashboard. Never use user_metadata for authorization.
begin;

-- SQL grants are separate from RLS. These privileges are safe because each write
-- is still constrained by the owner-only policies below.
grant select, insert, update, delete on public.movies, public.series, public.episodes to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'owner-media',
  'owner-media',
  true,
  2147483648,
  array['video/mp4','video/webm','video/quicktime','application/vnd.apple.mpegurl','application/x-mpegURL','image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "MILTVPLUS owner reads all movies" on public.movies;
create policy "MILTVPLUS owner reads all movies"
  on public.movies for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner inserts movies" on public.movies;
create policy "MILTVPLUS owner inserts movies"
  on public.movies for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner updates movies" on public.movies;
create policy "MILTVPLUS owner updates movies"
  on public.movies for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner deletes movies" on public.movies;
create policy "MILTVPLUS owner deletes movies"
  on public.movies for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner reads all series" on public.series;
create policy "MILTVPLUS owner reads all series"
  on public.series for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner inserts series" on public.series;
create policy "MILTVPLUS owner inserts series"
  on public.series for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner updates series" on public.series;
create policy "MILTVPLUS owner updates series"
  on public.series for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner deletes series" on public.series;
create policy "MILTVPLUS owner deletes series"
  on public.series for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner reads all episodes" on public.episodes;
create policy "MILTVPLUS owner reads all episodes"
  on public.episodes for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner inserts episodes" on public.episodes;
create policy "MILTVPLUS owner inserts episodes"
  on public.episodes for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner updates episodes" on public.episodes;
create policy "MILTVPLUS owner updates episodes"
  on public.episodes for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner deletes episodes" on public.episodes;
create policy "MILTVPLUS owner deletes episodes"
  on public.episodes for delete to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner uploads media" on storage.objects;
create policy "MILTVPLUS owner uploads media"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'owner-media' and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner updates media" on storage.objects;
create policy "MILTVPLUS owner updates media"
  on storage.objects for update to authenticated
  using (bucket_id = 'owner-media' and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner')
  with check (bucket_id = 'owner-media' and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

drop policy if exists "MILTVPLUS owner deletes media" on storage.objects;
create policy "MILTVPLUS owner deletes media"
  on storage.objects for delete to authenticated
  using (bucket_id = 'owner-media' and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner');

commit;
