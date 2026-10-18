// MILTVPLUS: idempotent M3U sync for live channels only.
// Deploy after migration 20261016110000_m3u_catalog_sync.sql.
// Requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and SYNC_SECRET.
// Only HTTPS direct HLS (.m3u8) entries are imported. This does NOT import VOD into movies/series.
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

type Source = {
  name: string;
  url: string;
  category: string;
  countryCode?: string;
};

const SOURCES: Source[] = [
  { name: "IPTV-org Deportes", url: "https://iptv-org.github.io/iptv/categories/sports.m3u", category: "Deportes" },
  { name: "IPTV-org Noticias", url: "https://iptv-org.github.io/iptv/categories/news.m3u", category: "Noticias" },
  { name: "IPTV-org Entretenimiento", url: "https://iptv-org.github.io/iptv/categories/entertainment.m3u", category: "Entretenimiento" },
  { name: "IPTV-org Películas (canales)", url: "https://iptv-org.github.io/iptv/categories/movies.m3u", category: "Cine" },
  { name: "IPTV-org Series (canales)", url: "https://iptv-org.github.io/iptv/categories/series.m3u", category: "Series" },
  { name: "IPTV-org Cine clásico", url: "https://iptv-org.github.io/iptv/categories/classic.m3u", category: "Clásicos" },
  { name: "IPTV-org Comedia", url: "https://iptv-org.github.io/iptv/categories/comedy.m3u", category: "Comedia" },
  { name: "IPTV-org Kids", url: "https://iptv-org.github.io/iptv/categories/kids.m3u", category: "Kids" },
  { name: "IPTV-org Animación", url: "https://iptv-org.github.io/iptv/categories/animation.m3u", category: "Anime y Animación" },
  { name: "IPTV-org Música", url: "https://iptv-org.github.io/iptv/categories/music.m3u", category: "Música" },
  { name: "IPTV-org Documentales", url: "https://iptv-org.github.io/iptv/categories/documentary.m3u", category: "Documentales" },
  { name: "IPTV-org Argentina", url: "https://iptv-org.github.io/iptv/countries/ar.m3u", category: "TV Argentina", countryCode: "AR" },
  { name: "IPTV-org Índice global", url: "https://iptv-org.github.io/iptv/index.m3u", category: "TV en Vivo" },
  { name: "Free-TV lista general", url: "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8", category: "TV en Vivo" },
];

// No global row cap: each source is fully processed and imported in bounded batches.
const BATCH_SIZE = 100;
const clean = (value: string | undefined) => (value ?? "").trim();

function attribute(line: string, key: string): string {
  const match = line.match(new RegExp('(?:^|\\s)' + key + '="([^"]*)"', "i"));
  return clean(match?.[1]);
}

async function stableHash(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function directHttpsHls(value: string): string | null {
  try {
    const parsed = new URL(value.trim());
    if (parsed.protocol !== "https:") return null;
    if (!parsed.pathname.toLowerCase().endsWith(".m3u8")) return null;
    if (parsed.username || parsed.password) return null;
    if (["localhost", "127.0.0.1", "::1"].includes(parsed.hostname.toLowerCase())) return null;
    return parsed.toString();
  } catch {
    return null;
  }
}

async function parsePlaylist(source: Source, body: string) {
  const entries: Array<Record<string, unknown>> = [];
  const lines = body.replace(/^\uFEFF/, "").split(/\r?\n/);
  let meta = "";
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith("#EXTINF:")) {
      meta = line;
      continue;
    }
    if (line.startsWith("#")) continue;
    if (!meta) continue;

    const streamUrl = directHttpsHls(line);
    const comma = meta.indexOf(",");
    const rawTitle = comma >= 0 ? meta.slice(comma + 1).trim() : "";
    const title = clean(rawTitle).replace(/[\u200e\u200f]/g, "");
    if (!streamUrl || !title) {
      meta = "";
      continue;
    }

    const tvgId = attribute(meta, "tvg-id").toLowerCase();
    const logoUrl = directHttpsHls(attribute(meta, "tvg-logo")) ??
      (() => {
        const rawLogo = attribute(meta, "tvg-logo");
        try {
          const parsed = new URL(rawLogo);
          return parsed.protocol === "https:" ? parsed.toString() : null;
        } catch {
          return null;
        }
      })();
    const groupTitle = attribute(meta, "group-title") || source.category;
    const countryCode = source.countryCode || attribute(meta, "tvg-country").split(/[;,]/)[0]?.trim().toUpperCase() || null;
    const identityKey = tvgId ? `m3u:${tvgId}` : `m3u:url:${await stableHash(streamUrl)}`;
    // Keep category membership independent: a sports channel can also belong
    // to its country/global list without one membership overwriting another.
    const categoryKey = source.category.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const sourceKey = `${identityKey}:category:${categoryKey}`;

    entries.push({
      source_key: sourceKey,
      source_name: source.name,
      group_title: groupTitle,
      country_code: countryCode,
      category: source.category,
      title,
      url_stream: streamUrl,
      logo: logoUrl,
      is_published: true,
    });
    meta = "";
  }
  return entries;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const expectedSecret = Deno.env.get("SYNC_SECRET");
  const suppliedSecret = req.headers.get("x-sync-secret");
  if (!expectedSecret || !suppliedSecret || suppliedSecret !== expectedSecret) {
    return json({ error: "Unauthorized catalog sync request." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Missing Supabase server secrets." }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const sourceResults: Array<{ source: string; fetched: number; parsed: number; accepted: number; deduplicated: number; rejected: number; error?: string }> = [];
  const selected: Array<Record<string, unknown>> = [];
  const seen = new Set<string>();

  // Keep network concurrency bounded so the public playlist hosts are not flooded.
  for (let start = 0; start < SOURCES.length; start += 4) {
    const group = SOURCES.slice(start, start + 4);
    const results = await Promise.all(group.map(async (source) => {
      try {
        const response = await fetch(source.url, {
          headers: { Accept: "application/x-mpegURL, audio/x-mpegurl, text/plain, */*" },
          signal: AbortSignal.timeout(20000),
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const text = await response.text();
        if (!text.trimStart().startsWith("#EXTM3U")) throw new Error("La respuesta no parece una lista M3U.");
        const parsed = await parsePlaylist(source, text);
        return { source, parsed, fetched: (text.match(/^#EXTINF:/gm) ?? []).length };
      } catch (error) {
        return {
          source,
          parsed: [] as Array<Record<string, unknown>>,
          fetched: 0,
          error: error instanceof Error ? error.message : "Error de descarga",
        };
      }
    }));

    for (const result of results) {
      let accepted = 0;
      for (const row of result.parsed) {
        const key = String(row.source_key ?? "");
        // Source order is intentional: genre-specific lists take priority over country/general lists.
        if (!key || seen.has(key)) continue;
        seen.add(key);
        selected.push(row);
        accepted++;
      }
      const parsed = result.parsed.length;
      sourceResults.push({
        source: result.source.name,
        fetched: result.fetched,
        parsed,
        accepted,
        deduplicated: Math.max(0, parsed - accepted),
        rejected: Math.max(0, result.fetched - parsed),
        ...(result.error ? { error: result.error } : {}),
      });
    }
  }

  if (!selected.length) {
    return json({
      ok: false,
      imported: 0,
      sources: sourceResults,
      error: "No se encontraron URLs HTTPS directas con extensión .m3u8; no se modificó el catálogo.",
    }, 422);
  }

  let imported = 0;
  for (let start = 0; start < selected.length; start += BATCH_SIZE) {
    const batch = selected.slice(start, start + BATCH_SIZE);
    const { error } = await supabase.from("channels").upsert(batch, { onConflict: "source_key" });
    if (error) {
      return json({
        ok: false,
        imported,
        attempted: selected.length,
        sources: sourceResults,
        error: `Falló la importación por lotes: ${error.message}`,
      }, 502);
    }
    imported += batch.length;
  }

  const failedSources = sourceResults
    .filter((result) => result.error)
    .map((result) => result.source);
  const rejectedRows = sourceResults.reduce((sum, result) => sum + result.rejected, 0);
  const sourceFetchComplete = failedSources.length === 0;
  const complete = sourceFetchComplete && rejectedRows === 0;
  return json({
    ok: complete,
    complete,
    sourceFetchComplete,
    imported,
    rejectedRows,
    failedSources,
    sources: sourceResults,
    note: "Se importaron solo canales en vivo con URL HTTPS .m3u8. Las fuentes M3U de películas/series quedan en channels como canales temáticos; no se insertaron registros falsos en movies/series. La importación no garantiza que cada emisión siga activa ni que cada proveedor autorice su redistribución.",
  }, complete ? 200 : 207);
});
