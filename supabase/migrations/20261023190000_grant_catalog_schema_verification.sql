-- The CI release gate checks required columns through PostgREST using the
-- server-side service_role key. RLS policies do not grant SQL privileges;
-- these explicit SELECT grants allow the verifier to inspect the catalog.
-- This does not grant anon/authenticated users any additional access.
GRANT SELECT ON TABLE
  public.channels,
  public.movies,
  public.series,
  public.episodes,
  public.content_submissions
TO service_role;
