-- MILTVPLUS QA: grant the isolated catalog-sync worker the minimum table privileges it needs.
-- Root cause observed in QA run: permission denied for table channels (SQLSTATE 42501).
-- This migration does not grant any permissions to anon/authenticated and must be applied to MILTVPLUS-QA only.

begin;

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; stop and inspect the selected QA project.';
  end if;
  if not exists (
    select 1 from pg_roles where rolname = 'service_role'
  ) then
    raise exception 'Supabase service_role is missing; refusing to apply catalog-sync grants.';
  end if;
end $$;

grant select, insert, update on table public.channels to service_role;

do $$
declare
  channels_sequence text;
begin
  channels_sequence := pg_get_serial_sequence('public.channels', 'id');
  if channels_sequence is not null then
    execute format('grant usage, select on sequence %s to service_role', channels_sequence);
  end if;

  if not has_table_privilege('service_role', 'public.channels', 'select')
     or not has_table_privilege('service_role', 'public.channels', 'insert')
     or not has_table_privilege('service_role', 'public.channels', 'update') then
    raise exception 'Catalog-sync privileges are still incomplete on public.channels.';
  end if;
end $$;

commit;
