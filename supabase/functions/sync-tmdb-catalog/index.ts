// MILTVPLUS catalog metadata sync. Deploy with TMDB_API_KEY and SYNC_SECRET secrets.
// Only metadata is imported. No stream URLs are inferred or invented.
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
  const pages = Math.max(1, Math.min(Number(request.pages ?? 1) || 1, 5));
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

  try {
    const [movieGenresResponse, tvGenresResponse] = await Promise.all([
      includeMovies ? api("genre/movie/list") : Promise.resolve({ genres: [] }),
      includeSeries ? api("genre/tv/list") : Promise.resolve({ genres: [] }),
    ]);
    const movieGenres = new Map<number, string>((movieGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));
    const tvGenres = new Map<number, string>((tvGenresResponse.genres ?? []).map((g: { id: number; name: string }) => [g.id, g.name]));

    let moviesProcessed = 0;
    let seriesProcessed = 0;
    for (let page = 1; page <= pages; page++) {
      if (includeMovies) {
        const data = await api(`movie/popular?page=${page}`);
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
          const { error } = await supabase.from("movies").upsert(rows, { onConflict: "tmdb_id" });
          if (error) throw new Error(`Supabase movies upsert failed: ${error.message}`);
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
        }
      }
    }

    return json({
      ok: true,
      pages,
      moviesProcessed,
      seriesProcessed,
      note: "Metadata imported. Movies without an authorized stream remain non-playable until an owner adds one.",
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Catalog sync failed." }, 502);
  }
});
