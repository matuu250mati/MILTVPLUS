-- Repair existing environments where an earlier migration granted table-wide
-- SELECT on community submissions. Keep only columns required by the public catalog.
-- The catalog orders by id/created_at and filters moderation_status, so those
-- columns must remain selectable even though they are not all rendered.
revoke select on table public.content_submissions from anon, authenticated;

grant select (
  id, title, description, stream_url, poster_url, duration_seconds,
  series_title, season_number, episode_number, media_type,
  moderation_status, created_at
) on public.content_submissions to anon, authenticated;
