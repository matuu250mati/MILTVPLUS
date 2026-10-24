// MILTVPLUS catalog metadata sync. Deploy with TMDB_API_KEY and SYNC_SECRET secrets.
// Only metadata is imported. No stream URLs are inferred or invented.
// Re-running this function updates the same rows by tmdb_id; it does not create stream access.
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

  let request: {
    pages?: number;
    includeMovies?: boolean;
    includeSeries?: boolean;
    includeEpisodes?: boolean;
    episodeSeriesLimit?: number;
  };
  try {
    request = await req.json();
  } catch {
    request = {};
  }
  const pages = Math.max(1, Math.min(Number(request.pages ?? 1) || 1, 5));
  const includeMovies = request.includeMovies !== false;
  const includeSeries = request.includeSeries !== false;
  const includeEpisodes = includeSeries && request.includeEpisodes !== false;
  // Caps TMDB calls per page so the Edge Function stays within its time limit.
  const episodeSeriesLimit = Math.max(1, Math.min(Number(request.episodeSeriesLimit ?? 5) || 5, 20));
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

  try {
    const [movieGenresResponse, tvGenresResponse] = await Promise.all([
      includeMovies ? api("genre/movie/list") : Promise.resolve({ genres: [] }),
      includeSeries ? api("genre/tv/list") : Promise.resolve({ genres: [] }),
    ]);
    const movieGenres = new Map<number, string>((movieGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));
    const tvGenres = new Map<number, string>((tvGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));

    let moviesProcessed = 0;
    let seriesProcessed = 0;
    let episodesProcessed = 0;
    for (let page = 1; page <= pages; page++) {
      if (includeMovies) {
        // Import current/popular titles plus year-scoped discovery so older popular
        // titles do not crowd out 2021-2026 releases and announced future films.
        // This imports metadata only; it never fabricates playback URLs.
        const movieSourcePaths = [
          `movie/popular?page=${page}`,
          `movie/now_playing?page=${page}`,
          `movie/upcoming?page=${page}`,
          ...[2021, 2022, 2023, 2024, 2025, 2026].map((year) =>
            `discover/movie?primary_release_year=${year}&region=AR&sort_by=popularity.desc&page=${page}`),
          `discover/movie?primary_release_date.gte=2027-01-01&primary_release_date.lte=2035-12-31&region=AR&sort_by=popularity.desc&page=${page}`,
        ];
        const sourceResponses = await Promise.all(movieSourcePaths.map(api));
        const uniqueItems = new Map<number, any>();
        for (const source of sourceResponses) {
          for (const item of source.results ?? []) {
            const id = Number(item.id);
            if (id > 0) uniqueItems.set(id, item);
          }
        }
        const data = { results: [...uniqueItems.values()] };
        const rows = (data.results ?? []).map((item: any) => ({
          tmdb_id: Number(item.id),
          title: String(item.title ?? item.original_title ?? "").trim(),
          synopsis: String(item.overview ?? ""),
          category: "Películas",
          genres: (item.genre_ids ?? []).map((id: number) => movieGenres.get(id)).filter(Boolean),
          logo: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : null,
          backdrop_url: item.backdrop_path ? `https://image.tmdb.org/t/p/w1280${item.backdrop_path}` : null,
          // Deliberately empty until an authorized stream is added by the catalog owner.
          url_stream: "",
          release_year: item.release_date ? Number(String(item.release_date).slice(0, 4)) || null : null,
          duration_seconds: null,
          country_code: "AR",
          is_published: true,
        })).filter((row: any) => row.tmdb_id > 0 && row.title.length > 0);
        if (rows.length) {
          // Never overwrite a stream URL an owner already added: existing rows get metadata only.
          const { data: existing, error: lookupError } = await supabase
            .from("movies")
            .select("tmdb_id, url_stream, duration_seconds")
            .in("tmdb_id", rows.map((row: any) => row.tmdb_id));
          if (lookupError) throw new Error(`Supabase movies lookup failed: ${lookupError.message}`);
          const existingById = new Map<number, any>(
            (existing ?? []).map((row: any) => [Number(row.tmdb_id), row]),
          );
          const fresh = rows.filter((row: any) => !existingById.has(row.tmdb_id));
          // Carry forward owner-managed playback fields explicitly: upsert can
          // otherwise write NULL for omitted columns on conflicting rows.
          const known = rows
            .filter((row: any) => existingById.has(row.tmdb_id))
            .map(({ url_stream: _urlStream, duration_seconds: _duration, ...metadata }: any) => {
              const prior = existingById.get(metadata.tmdb_id);
              return {
                ...metadata,
                url_stream: prior.url_stream ?? "",
                duration_seconds: prior.duration_seconds ?? null,
              };
            });
          if (fresh.length) {
            const { error } = await supabase.from("movies").upsert(fresh, { onConflict: "tmdb_id" });
            if (error) throw new Error(`Supabase movies insert failed: ${error.message}`);
          }
          if (known.length) {
            const { error } = await supabase.from("movies").upsert(known, { onConflict: "tmdb_id" });
            if (error) throw new Error(`Supabase movies update failed: ${error.message}`);
          }
          moviesProcessed += rows.length;
        }
      }

      if (includeSeries) {
        const data = await api(`tv/popular?page=${page}`);
        const rows = (data.results ?? []).map((item: any) => ({
          tmdb_id: Number(item.id),
          title: String(item.name ?? item.original_name ?? "").trim(),
          synopsis: String(item.overview ?? ""),
          category: "Series",
          genres: (item.genre_ids ?? []).map((id: number) => tvGenres.get(id)).filter(Boolean),
          logo: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : null,
          backdrop_url: item.backdrop_path ? `https://image.tmdb.org/t/p/w1280${item.backdrop_path}` : null,
          release_year: item.first_air_date ? Number(String(item.first_air_date).slice(0, 4)) || null : null,
          country_code: "AR",
          is_published: true,
        })).filter((row: any) => row.tmdb_id > 0 && row.title.length > 0);
        if (rows.length) {
          const { error } = await supabase.from("series").upsert(rows, { onConflict: "tmdb_id" });
          if (error) throw new Error(`Supabase series upsert failed: ${error.message}`);
          seriesProcessed += rows.length;

          if (includeEpisodes) {
            const { data: seriesRows, error: seriesLookupError } = await supabase
              .from("series")
              .select("id, tmdb_id")
              .in("tmdb_id", rows.map((row: any) => row.tmdb_id))
              .limit(episodeSeriesLimit);
            if (seriesLookupError) throw new Error(`Supabase series lookup failed: ${seriesLookupError.message}`);
            for (const seriesRow of seriesRows ?? []) {
              const details = await api(`tv/${seriesRow.tmdb_id}`);
              const seasons = (details.seasons ?? [])
                .filter((season: any) => Number(season.season_number) > 0)
                .slice(0, 12);
              for (const season of seasons) {
                const seasonData = await api(`tv/${seriesRow.tmdb_id}/season/${season.season_number}`);
                const episodeRows = (seasonData.episodes ?? [])
                  .map((episode: any) => ({
                    series_id: seriesRow.id,
                    season_number: Number(episode.season_number ?? season.season_number),
                    episode_number: Number(episode.episode_number),
                    title: String(episode.name ?? "").trim() || `Episodio ${episode.episode_number}`,
                    synopsis: String(episode.overview ?? ""),
                    logo: episode.still_path ? `https://image.tmdb.org/t/p/w500${episode.still_path}` : null,
                    // Empty until an authorized stream is added by the catalog owner.
                    url_stream: "",
                    duration_seconds: episode.runtime ? Number(episode.runtime) * 60 : null,
                    is_published: true,
                  }))
                  .filter((row: any) => row.season_number > 0 && row.episode_number > 0);
                if (!episodeRows.length) continue;

                // Keep stream URLs already set on existing episodes.
                const { data: existingEpisodes, error: episodeLookupError } = await supabase
                  .from("episodes")
                  .select("episode_number, url_stream, duration_seconds")
                  .eq("series_id", seriesRow.id)
                  .eq("season_number", episodeRows[0].season_number);
                if (episodeLookupError) throw new Error(`Supabase episodes lookup failed: ${episodeLookupError.message}`);
                const existingEpisodeByNumber = new Map<number, any>(
                  (existingEpisodes ?? []).map((row: any) => [Number(row.episode_number), row]),
                );
                const freshEpisodes = episodeRows.filter((row: any) => !existingEpisodeByNumber.has(row.episode_number));
                // Preserve manually configured streams and durations on existing episodes.
                const knownEpisodes = episodeRows
                  .filter((row: any) => existingEpisodeByNumber.has(row.episode_number))
                  .map(({ url_stream: _urlStream, duration_seconds: _duration, ...metadata }: any) => {
                    const prior = existingEpisodeByNumber.get(metadata.episode_number);
                    return {
                      ...metadata,
                      url_stream: prior.url_stream ?? "",
                      duration_seconds: prior.duration_seconds ?? null,
                    };
                  });
                const conflict = "series_id,season_number,episode_number";
                if (freshEpisodes.length) {
                  const { error } = await supabase.from("episodes").upsert(freshEpisodes, { onConflict: conflict });
                  if (error) throw new Error(`Supabase episodes insert failed: ${error.message}`);
                }
                if (knownEpisodes.length) {
                  const { error } = await supabase.from("episodes").upsert(knownEpisodes, { onConflict: conflict });
                  if (error) throw new Error(`Supabase episodes update failed: ${error.message}`);
                }
                episodesProcessed += episodeRows.length;
              }
            }
          }
        }
      }
    }

    return json({
      ok: true,
      pages,
      moviesProcessed,
      seriesProcessed,
      episodesProcessed,
      note: "Metadata imported from popular, now-playing, upcoming, and year-scoped movie discovery (2021-2035); existing stream URLs were preserved. Metadata does not grant playback rights, and titles without an authorized stream remain non-playable.",
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Catalog sync failed." }, 502);
  }
});
