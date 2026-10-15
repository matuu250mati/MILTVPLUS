-- User-owned channel sync submissions. These are pending proposals, not public catalogue rows.
begin;

create table if not exists public.channel_sync_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_brand text not null,
  device_model text not null,
  connection_type text not null,
  source_host text not null default '',
  channel_count integer not null default 0 check (channel_count >= 0 and channel_count <= 5000),
  channels jsonb not null default '[]'::jsonb check (jsonb_typeof(channels) = 'array'),
  status text not null default 'pending_review'
    check (status in ('pending_review', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.channel_sync_submissions enable row level security;
revoke all on public.channel_sync_submissions from anon;
grant select, insert on public.channel_sync_submissions to authenticated;

drop policy if exists "Users submit own channel sync" on public.channel_sync_submissions;
create policy "Users submit own channel sync"
  on public.channel_sync_submissions for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending_review');

drop policy if exists "Users read own channel sync" on public.channel_sync_submissions;
create policy "Users read own channel sync"
  on public.channel_sync_submissions for select to authenticated
  using (auth.uid() = user_id);

commit;
