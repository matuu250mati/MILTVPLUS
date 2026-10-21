// MILTVPLUS catalog metadata sync.
// Metadata is sourced from TMDB. Playback URLs are never inferred or copied from third-party streaming sites.
// Existing owner-configured stream URLs and publication decisions must survive metadata refreshes.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const expectedSecret = Deno.env.get("SYNC_SECRET");
  const suppliedSecret = req.headers.get("x-sync-secret");
  if (!expectedSecret || !suppliedSecret || suppliedSecret !== expectedSecret) {
    return json({ error: "Unauthorized catalog sync request." }, 401);
  }

  const tmdbKey = Deno.env.get("TMDB_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!tmdbKey || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "Missing TMDB_API_KEY or Supabase server secrets." }, 500);
  }

  let request: { pages?: number; includeMovies?: boolean; includeSeries?: boolean };
  try {
    request = await req.json();
  } catch {
    request = {};
  }
  const requestedPages = Number(request.pages ?? 5);
  const pages = Math.max(1, Math.min(Number.isFinite(requestedPages) ? Math.floor(requestedPages) : 5, 5));
  const includeMovies = request.includeMovies !== false;
  const includeSeries = request.includeSeries !== false;
  if (!includeMovies && !includeSeries) return json({ error: "Select movies, series, or both." }, 400);

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const api = async (path: string) => {
    const url = new URL(`https://api.themoviedb.org/3/${path}`);
    url.searchParams.set("api_key", tmdbKey);
    url.searchParams.set("language", "es-ES");
    const response = await fetch(url, { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`TMDB request failed (${response.status}) for ${path.split("?")[0]}`);
    return await response.json();
  };

  // Existing records are refreshed only with descriptive metadata. Playback URLs,
  // stream mirrors, and the owner's publication decision are deliberately omitted.
  const saveMetadata = async (
    table: "movies" | "series",
    rows: Array<Record<string, unknown>>,
    hasStreamUrl: boolean,
  ) => {
    if (!rows.length) return { inserted: 0, updated: 0 };
    const ids = rows.map((row) => Number(row.tmdb_id)).filter((id) => Number.isInteger(id) && id > 0);
    const { data: existingRows, error: lookupError } = await supabase
      .from(table)
      .select("tmdb_id")
      .in("tmdb_id", ids);
    if (lookupError) throw new Error(`Supabase ${table} lookup failed: ${lookupError.message}`);

    const existingIds = new Set((existingRows ?? []).map((row: { tmdb_id: number | string }) => Number(row.tmdb_id)));
    const existing = rows.filter((row) => existingIds.has(Number(row.tmdb_id)));
    const fresh = rows
      .filter((row) => !existingIds.has(Number(row.tmdb_id)))
      .map((row) => ({
        ...row,
        ...(hasStreamUrl ? { url_stream: "", stream_urls: [] } : {}),
        is_published: true,
      }));

    if (existing.length) {
      const { error } = await supabase.from(table).upsert(existing, { onConflict: "tmdb_id" });
      if (error) throw new Error(`Supabase ${table} metadata update failed: ${error.message}`);
    }
    if (fresh.length) {
      const { error } = await supabase.from(table).insert(fresh);
      if (error) throw new Error(`Supabase ${table} metadata insert failed: ${error.message}`);
    }
    return { inserted: fresh.length, updated: existing.length };
  };

  try {
    const [movieGenresResponse, tvGenresResponse] = await Promise.all([
      includeMovies ? api("genre/movie/list") : Promise.resolve({ genres: [] }),
      includeSeries ? api("genre/tv/list") : Promise.resolve({ genres: [] }),
    ]);
    const movieGenres = new Map<number, string>((movieGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));
    const tvGenres = new Map<number, string>((tvGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));

    const totals = {
      pagesPerSource: pages,
      movieSources: includeMovies ? ["movie/popular", "movie/top_rated", "movie/now_playing", "movie/upcoming"] : [],
      seriesSources: includeSeries ? ["tv/popular", "tv/top_rated", "tv/on_the_air", "tv/airing_today"] : [],
      moviesInserted: 0,
      moviesUpdated: 0,
      seriesInserted: 0,
      seriesUpdated: 0,
    };

    // Four complementary lists per type widen discovery across popular, acclaimed,
    // currently released, and upcoming/on-air titles. Five pages per list caps
    // the run at 40 media-list requests plus genre lookups. Upserts are idempotent.
    for (const source of totals.movieSources) {
      for (let page = 1; page <= pages; page++) {
        const data = await api(`${source}?page=${page}`);
        const rows = (data.results ?? []).map((item: any) => {
          const title = String(item.title ?? item.original_title ?? "").trim();
          const synopsis = String(item.overview ?? "").trim();
          const genres = (item.genre_ids ?? [])
            .map((id: number) => movieGenres.get(id))
            .filter((name: string | undefined): name is string => Boolean(name));
          const releaseYear = item.release_date
            ? Number(String(item.release_date).slice(0, 4)) || null
            : null;
          return {
            tmdb_id: Number(item.id),
            title,
            category: "Películas",
            ...(synopsis ? { synopsis } : {}),
            ...(genres.length ? { genres } : {}),
            ...(item.poster_path ? { logo: `https://image.tmdb.org/t/p/w500${item.poster_path}` } : {}),
            ...(item.backdrop_path ? { backdrop_url: `https://image.tmdb.org/t/p/w1280${item.backdrop_path}` } : {}),
            ...(releaseYear ? { release_year: releaseYear } : {}),
          };
        }).filter((row: any) => row.tmdb_id > 0 && row.title.length > 0);
        const saved = await saveMetadata("movies", rows, true);
        totals.moviesInserted += saved.inserted;
        totals.moviesUpdated += saved.updated;
      }
    }

    for (const source of totals.seriesSources) {
      for (let page = 1; page <= pages; page++) {
        const data = await api(`${source}?page=${page}`);
        const rows = (data.results ?? []).map((item: any) => {
          const title = String(item.name ?? item.original_name ?? "").trim();
          const synopsis = String(item.overview ?? "").trim();
          const genres = (item.genre_ids ?? [])
            .map((id: number) => tvGenres.get(id))
            .filter((name: string | undefined): name is string => Boolean(name));
          const releaseYear = item.first_air_date
            ? Number(String(item.first_air_date).slice(0, 4)) || null
            : null;
          return {
            tmdb_id: Number(item.id),
            title,
            category: "Series",
            ...(synopsis ? { synopsis } : {}),
            ...(genres.length ? { genres } : {}),
            ...(item.poster_path ? { logo: `https://image.tmdb.org/t/p/w500${item.poster_path}` } : {}),
            ...(item.backdrop_path ? { backdrop_url: `https://image.tmdb.org/t/p/w1280${item.backdrop_path}` } : {}),
            ...(releaseYear ? { release_year: releaseYear } : {}),
          };
        }).filter((row: any) => row.tmdb_id > 0 && row.title.length > 0);
        const saved = await saveMetadata("series", rows, false);
        totals.seriesInserted += saved.inserted;
        totals.seriesUpdated += saved.updated;
      }
    }

    return json({
      ok: true,
      ...totals,
      note: "TMDB metadata synchronized. Existing playback URLs and publication states were preserved; new movie rows need an authorized playback source before they can play.",
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Catalog sync failed." }, 502);
  }
});
