-- Add ordered playback mirrors to published live TV channels.
-- Existing primary URLs are retained as the first candidate; no source URLs are invented.
-- Some existing databases created stream_urls as text[] before this migration.
-- Normalize that legacy column to jsonb while preserving its stored values.
begin;

alter table public.channels
  add column if not exists stream_urls jsonb not null default '[]'::jsonb;

do $$
declare
  stream_urls_data_type text;
begin
  select data_type
    into stream_urls_data_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'channels'
    and column_name = 'stream_urls';

  if stream_urls_data_type = 'ARRAY' then
    alter table public.channels
      alter column stream_urls drop default;

    alter table public.channels
      alter column stream_urls type jsonb
      using to_jsonb(stream_urls);

    alter table public.channels
      alter column stream_urls set default '[]'::jsonb;
  end if;
end
$$;

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
