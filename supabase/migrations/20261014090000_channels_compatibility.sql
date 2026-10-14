-- MILTVPLUS: compatibility migration for an existing channels table.
-- Non-destructive: preserves rows and maps common legacy column names.
-- Review the resulting columns and row counts after running in Supabase SQL Editor.
begin;

do $migration$
declare
  source_col text;
  has_title boolean;
  has_url_stream boolean;
  has_is_published boolean;
  has_sort_order boolean;
begin
  if to_regclass('public.channels') is null then
    raise exception 'public.channels does not exist. Apply the base schema first, or inspect the actual database before proceeding.';
  end if;

  select exists (select 1 from information_schema.columns where table_schema='public' and table_name='channels' and column_name='title') into has_title;
  select exists (select 1 from information_schema.columns where table_schema='public' and table_name='channels' and column_name='url_stream') into has_url_stream;
  select exists (select 1 from information_schema.columns where table_schema='public' and table_name='channels' and column_name='is_published') into has_is_published;
  select exists (select 1 from information_schema.columns where table_schema='public' and table_name='channels' and column_name='sort_order') into has_sort_order;

  if not has_title then
    alter table public.channels add column title text;
    select column_name into source_col
    from information_schema.columns
    where table_schema='public' and table_name='channels'
      and column_name in ('channel_title','channel_name','name')
    order by case column_name when 'channel_title' then 1 when 'channel_name' then 2 else 3 end
    limit 1;
    if source_col is null then
      raise exception 'Cannot map a channel name to title. Inspect public.channels columns and create a reviewed mapping; transaction rolled back.';
    end if;
    execute format('update public.channels set title = %I::text where title is null', source_col);
  end if;

  if not has_url_stream then
    alter table public.channels add column url_stream text;
    select column_name into source_col
    from information_schema.columns
    where table_schema='public' and table_name='channels'
      and column_name in ('stream_url','streaming_url','source_url','url','m3u_url')
    order by case column_name when 'stream_url' then 1 when 'streaming_url' then 2 when 'source_url' then 3 when 'url' then 4 else 5 end
    limit 1;
    if source_col is null then
      raise exception 'Cannot map a stream URL to url_stream. Inspect public.channels columns and create a reviewed mapping; transaction rolled back.';
    end if;
    execute format('update public.channels set url_stream = %I::text where url_stream is null', source_col);
  end if;

  -- Preserve existing channel artwork when legacy schema uses logo_url.
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='channels' and column_name='logo'
  ) then
    alter table public.channels add column logo text;
    select column_name into source_col
    from information_schema.columns
    where table_schema='public' and table_name='channels'
      and column_name in ('logo_url', 'image_url', 'icon_url', 'thumbnail_url')
    order by case column_name when 'logo_url' then 1 when 'image_url' then 2 when 'icon_url' then 3 else 4 end
    limit 1;
    if source_col is not null then
      execute format('update public.channels set logo = %I::text where logo is null', source_col);
    end if;
  end if;

  if not has_is_published then
    alter table public.channels add column is_published boolean not null default false;
    select column_name into source_col
    from information_schema.columns
    where table_schema='public' and table_name='channels'
      and column_name in ('is_active','enabled','published','status')
    order by case column_name when 'is_active' then 1 when 'enabled' then 2 when 'published' then 3 else 4 end
    limit 1;
    if source_col is not null then
      -- Text statuses (active/published) and boolean-like legacy columns both map safely.
      execute format(
        'update public.channels set is_published = lower(coalesce(%I::text, '''')) in (''true'', ''t'', ''1'', ''yes'', ''published'', ''active'', ''approved'', ''live'')',
        source_col
      );
    end if;
  end if;

  if not has_sort_order then
    alter table public.channels add column sort_order integer not null default 0;
    select column_name into source_col
    from information_schema.columns
    where table_schema='public' and table_name='channels'
      and column_name in ('position','order_index','display_order','rank')
    order by case column_name when 'position' then 1 when 'order_index' then 2 when 'display_order' then 3 else 4 end
    limit 1;
    if source_col is not null then
      execute format('update public.channels set sort_order = coalesce(%I::integer, 0)', source_col);
    end if;
  end if;

  if exists (select 1 from public.channels where title is null or btrim(title) = '') then
    raise exception 'Some channels have no usable name. Migration rolled back to avoid losing or inventing data.';
  end if;
  if exists (select 1 from public.channels where url_stream is null or btrim(url_stream) = '') then
    raise exception 'Some channels have no usable stream URL. Migration rolled back to avoid inventing URLs.';
  end if;

  alter table public.channels alter column title set not null;
  alter table public.channels alter column url_stream set not null;
  alter table public.channels enable row level security;
  grant select on public.channels to anon, authenticated;

  drop policy if exists "Authenticated users read published channels" on public.channels;
  drop policy if exists "Public users read published channels" on public.channels;
  create policy "Public users read published channels"
    on public.channels for select to anon, authenticated
    using (is_published);

  create index if not exists channels_published_order_idx
    on public.channels (is_published, sort_order, title);
end
$migration$;

commit;
