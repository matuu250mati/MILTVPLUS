-- Add ordered playback mirrors to published live TV channels.
-- Existing primary URLs are retained as the first candidate; no source URLs are invented.
begin;

alter table public.channels
  add column if not exists stream_urls jsonb not null default '[]'::jsonb;

update public.channels
set stream_urls = jsonb_build_array(url_stream)
where (stream_urls is null or stream_urls = '[]'::jsonb)
  and url_stream is not null
  and btrim(url_stream) <> '';

alter table public.channels
  drop constraint if exists channels_stream_urls_array_check;
alter table public.channels
  add constraint channels_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

comment on column public.channels.stream_urls is
  'Ordered HTTPS playback URLs for authorized live-channel mirrors. url_stream remains the primary URL.';

commit;
