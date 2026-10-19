-- MILTVPLUS QA: preserve ordered live-channel playback mirrors.
-- Non-destructive: keeps url_stream as the primary URL and backfills it into stream_urls.
-- Apply to MILTVPLUS-QA only after confirming the dashboard project ref.
begin;

do $$
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist; inspect the QA schema before applying this migration.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='channels' and column_name='url_stream'
  ) then
    raise exception 'public.channels.url_stream is missing; do not guess the source URL column.';
  end if;
end $$;

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
  'Ordered candidate playback URLs for this live channel. url_stream remains the primary URL; mirrors are retained for fallback.';

commit;
