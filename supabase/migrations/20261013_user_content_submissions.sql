create table if not exists public.content_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_type text not null check (media_type in ('movie', 'episode')),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  description text not null check (char_length(btrim(description)) between 1 and 3000),
  stream_url text not null check (stream_url ~ '^https://[^[:space:]]+$'),
  poster_url text check (poster_url is null or poster_url ~ '^https://[^[:space:]]+$'),
  duration_seconds integer not null check (duration_seconds between 60 and 6000000),
  series_title text,
  season_number integer,
  episode_number integer,
  rights_confirmed boolean not null default false,
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  constraint content_submission_rights check (rights_confirmed),
  constraint content_submission_episode_fields check (
    (media_type = 'movie' and series_title is null and season_number is null and episode_number is null)
    or
    (media_type = 'episode'
      and series_title is not null
      and char_length(btrim(series_title)) between 1 and 160
      and season_number is not null and season_number > 0
      and episode_number is not null and episode_number > 0)
  )
);

alter table public.content_submissions enable row level security;

grant select on public.content_submissions to anon;
grant select, insert on public.content_submissions to authenticated;

create policy "Submit own pending content" on public.content_submissions
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and rights_confirmed
    and moderation_status = 'pending'
  );

create policy "Read own submissions" on public.content_submissions
  for select to authenticated
  using (auth.uid() = user_id);

create policy "Public users read approved submissions" on public.content_submissions
  for select to anon, authenticated
  using (moderation_status = 'approved');

-- Moderators can change only the review decision, not submitted metadata or URLs.
revoke update on public.content_submissions from authenticated;
grant update (moderation_status) on public.content_submissions to authenticated;

create policy "Moderators read submissions" on public.content_submissions
  for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'));

create policy "Moderators review submissions" on public.content_submissions
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'))
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator')
    and moderation_status in ('approved', 'rejected')
  );
