-- Provision the bucket used by the owner publishing screen.
-- Public reads are required because the app stores getPublicUrl() in catalog rows.
-- Writes remain restricted to authenticated JWTs with the server-managed owner role.
begin;

insert into storage.buckets (id, name, public)
values ('owner-media', 'owner-media', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "MILTVPLUS owner uploads owner-media" on storage.objects;
create policy "MILTVPLUS owner uploads owner-media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'owner-media'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner'
  );

drop policy if exists "MILTVPLUS owner updates owner-media" on storage.objects;
create policy "MILTVPLUS owner updates owner-media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'owner-media'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner'
  )
  with check (
    bucket_id = 'owner-media'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner'
  );

drop policy if exists "MILTVPLUS owner deletes owner-media" on storage.objects;
create policy "MILTVPLUS owner deletes owner-media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'owner-media'
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'owner'
  );

commit;
