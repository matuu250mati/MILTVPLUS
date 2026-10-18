-- Add ordered playback mirrors to published live TV channels.
-- Existing primary URLs are retained as the first candidate; no source URLs are invented.
-- Compatibility: some existing databases have stream_urls as text[] instead of jsonb.
begin;

alter table public.channels
  add column if not exists stream_urls jsonb;

do $migration$
declare
  stream_urls_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
    into stream_urls_type
  from pg_attribute a
  where a.attrelid = 'public.channels'::regclass
    and a.attname = 'stream_urls'
    and not a.attisdropped;

  if stream_urls_type = 'text[]' then
    -- Preserve every existing mirror URL while converting the array representation.
    alter table public.channels alter column stream_urls drop default;
    alter table public.channels
      alter column stream_urls type jsonb
      using to_jsonb(stream_urls);
  elsif stream_urls_type <> 'jsonb' then
    raise exception 'Unsupported public.channels.stream_urls type: %. Expected jsonb or text[]. No migration changes committed.', stream_urls_type;
  end if;
end
$migration$;

alter table public.channels
  alter column stream_urls set default '[]'::jsonb;

update public.channels
set stream_urls = '[]'::jsonb
where stream_urls is null;

update public.channels
set stream_urls = jsonb_build_array(url_stream)
where stream_urls = '[]'::jsonb
  and url_stream is not null
  and btrim(url_stream) <> '';

alter table public.channels
  alter column stream_urls set not null;

alter table public.channels
  drop constraint if exists channels_stream_urls_array_check;
alter table public.channels
  add constraint channels_stream_urls_array_check
  check (jsonb_typeof(stream_urls) = 'array');

comment on column public.channels.stream_urls is
  'Ordered playback URLs for authorized live-channel mirrors. url_stream remains the primary URL.';

commit;
