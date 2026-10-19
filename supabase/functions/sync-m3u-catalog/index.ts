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
  { name: "IPTV-org México", url: "https://iptv-org.github.io/iptv/countries/mx.m3u", category: "TV México", countryCode: "MX" },
  { name: "IPTV-org Bolivia", url: "https://iptv-org.github.io/iptv/countries/bo.m3u", category: "TV Bolivia", countryCode: "BO" },
  { name: "IPTV-org Brasil", url: "https://iptv-org.github.io/iptv/countries/br.m3u", category: "TV Brasil", countryCode: "BR" },
  { name: "IPTV-org Chile", url: "https://iptv-org.github.io/iptv/countries/cl.m3u", category: "TV Chile", countryCode: "CL" },
  { name: "IPTV-org Colombia", url: "https://iptv-org.github.io/iptv/countries/co.m3u", category: "TV Colombia", countryCode: "CO" },
  { name: "IPTV-org Costa Rica", url: "https://iptv-org.github.io/iptv/countries/cr.m3u", category: "TV Costa Rica", countryCode: "CR" },
  { name: "IPTV-org Cuba", url: "https://iptv-org.github.io/iptv/countries/cu.m3u", category: "TV Cuba", countryCode: "CU" },
  { name: "IPTV-org República Dominicana", url: "https://iptv-org.github.io/iptv/countries/do.m3u", category: "TV República Dominicana", countryCode: "DO" },
  { name: "IPTV-org Ecuador", url: "https://iptv-org.github.io/iptv/countries/ec.m3u", category: "TV Ecuador", countryCode: "EC" },
  { name: "IPTV-org El Salvador", url: "https://iptv-org.github.io/iptv/countries/sv.m3u", category: "TV El Salvador", countryCode: "SV" },
  { name: "IPTV-org Guatemala", url: "https://iptv-org.github.io/iptv/countries/gt.m3u", category: "TV Guatemala", countryCode: "GT" },
  { name: "IPTV-org Honduras", url: "https://iptv-org.github.io/iptv/countries/hn.m3u", category: "TV Honduras", countryCode: "HN" },
  { name: "IPTV-org Nicaragua", url: "https://iptv-org.github.io/iptv/countries/ni.m3u", category: "TV Nicaragua", countryCode: "NI" },
  { name: "IPTV-org Panamá", url: "https://iptv-org.github.io/iptv/countries/pa.m3u", category: "TV Panamá", countryCode: "PA" },
  { name: "IPTV-org Paraguay", url: "https://iptv-org.github.io/iptv/countries/py.m3u", category: "TV Paraguay", countryCode: "PY" },
  { name: "IPTV-org Perú", url: "https://iptv-org.github.io/iptv/countries/pe.m3u", category: "TV Perú", countryCode: "PE" },
  { name: "IPTV-org Puerto Rico", url: "https://iptv-org.github.io/iptv/countries/pr.m3u", category: "TV Puerto Rico", countryCode: "PR" },
  { name: "IPTV-org Uruguay", url: "https://iptv-org.github.io/iptv/countries/uy.m3u", category: "TV Uruguay", countryCode: "UY" },
  { name: "IPTV-org Venezuela", url: "https://iptv-org.github.io/iptv/countries/ve.m3u", category: "TV Venezuela", countryCode: "VE" },
  { name: "IPTV-org Estados Unidos", url: "https://iptv-org.github.io/iptv/countries/us.m3u", category: "TV Estados Unidos", countryCode: "US" },
  { name: "IPTV-org Canadá", url: "https://iptv-org.github.io/iptv/countries/ca.m3u", category: "TV Canadá", countryCode: "CA" },
  { name: "IPTV-org España", url: "https://iptv-org.github.io/iptv/countries/es.m3u", category: "TV España", countryCode: "ES" },
  { name: "IPTV-org Reino Unido", url: "https://iptv-org.github.io/iptv/countries/uk.m3u", category: "TV Reino Unido", countryCode: "GB" },
  { name: "IPTV-org Francia", url: "https://iptv-org.github.io/iptv/countries/fr.m3u", category: "TV Francia", countryCode: "FR" },
  { name: "IPTV-org Alemania", url: "https://iptv-org.github.io/iptv/countries/de.m3u", category: "TV Alemania", countryCode: "DE" },
  { name: "IPTV-org Italia", url: "https://iptv-org.github.io/iptv/countries/it.m3u", category: "TV Italia", countryCode: "IT" },
  { name: "IPTV-org Portugal", url: "https://iptv-org.github.io/iptv/countries/pt.m3u", category: "TV Portugal", countryCode: "PT" },
  { name: "IPTV-org Japón", url: "https://iptv-org.github.io/iptv/countries/jp.m3u", category: "TV Japón", countryCode: "JP" },
  { name: "IPTV-org Australia", url: "https://iptv-org.github.io/iptv/countries/au.m3u", category: "TV Australia", countryCode: "AU" },
  { name: "Free-TV lista general", url: "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8", category: "TV en Vivo" },
];

const BATCH_SIZE = 500;
const clean = (value: string | undefined) => (value ?? "").trim();

// M3U country metadata is inconsistent: it may contain ISO-2 codes or full names.
// Unknown countries use ISO 3166-1 user-assigned code ZZ instead of being mislabeled Argentina.
function normalizeCountryCode(value: string | undefined): string {
  const raw = clean(value).split(/[;,]/)[0].trim().toLowerCase().replace(/\./g, "");
  if (/^[a-z]{2}$/i.test(raw)) return raw.toUpperCase();
  const aliases: Record<string, string> = {
    argentina: "AR", arg: "AR", méxico: "MX", mexico: "MX", mex: "MX",
    brasil: "BR", brazil: "BR", bra: "BR", chile: "CL", chl: "CL",
    uruguay: "UY", ury: "UY", paraguay: "PY", pry: "PY", bolivia: "BO", bol: "BO",
    perú: "PE", peru: "PE", per: "PE", colombia: "CO", col: "CO",
    ecuador: "EC", ecu: "EC", venezuela: "VE", ven: "VE",
    "united states": "US", "united states of america": "US", usa: "US",
    "united kingdom": "GB", uk: "GB", gbr: "GB", britain: "GB", canada: "CA", can: "CA",
    españa: "ES", spain: "ES", esp: "ES", francia: "FR", france: "FR", fra: "FR",
    alemania: "DE", germany: "DE", deu: "DE", italia: "IT", italy: "IT", ita: "IT",
    portugal: "PT", prt: "PT", japón: "JP", japon: "JP", japan: "JP", jpn: "JP",
    china: "CN", chn: "CN", india: "IN", ind: "IN", australia: "AU", aus: "AU",
    "new zealand": "NZ", nzl: "NZ", rusia: "RU", russia: "RU", rus: "RU",
    "south korea": "KR", kor: "KR", "corea del sur": "KR", "south africa": "ZA", zaf: "ZA",
    "puerto rico": "PR", pri: "PR", cuba: "CU", internacional: "ZZ", international: "ZZ",
  };
  return aliases[raw] ?? "ZZ";
}

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
    // The channels.country_code column is NOT NULL; PostgreSQL defaults do not apply when an explicit null is sent.
    const countryCode = source.countryCode || normalizeCountryCode(attribute(meta, "tvg-country"));
    // A channel may belong to several genre/country playlists. Scope the stable key
    // to the category so an upsert in one playlist cannot erase its other category row.
    const categoryKey = source.category.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const sourceKey = tvgId
      ? `m3u:${tvgId}:category:${categoryKey}`
      : `m3u:url:${await stableHash(streamUrl)}:category:${categoryKey}`;

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

  // Optional read-only preflight: fetch and parse every configured source but do not touch the database.
  const requestBody = await req.clone().json().catch(() => ({})) as {
    dry_run?: unknown;
    confirm_sync?: unknown;
  };
  const dryRun = requestBody?.dry_run === true;
  const liveSyncConfirmed = requestBody?.confirm_sync === "MILTVPLUS-QA";

  const expectedSecret = Deno.env.get("SYNC_SECRET");
  const suppliedSecret = req.headers.get("x-sync-secret");
  if (!expectedSecret || !suppliedSecret || suppliedSecret !== expectedSecret) {
    return json({ error: "Unauthorized catalog sync request." }, 401);
  }

  if (!dryRun && !liveSyncConfirmed) {
    return json({
      error: "Explicit mode required. Send { dry_run: true } for a read-only preflight or { confirm_sync: 'MILTVPLUS-QA' } to authorize a live QA catalog sync.",
      writePerformed: false,
    }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Missing Supabase server secrets." }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const sourceResults: Array<{ source: string; fetched: number; accepted: number; rejected: number; duplicates: number; error?: string; warning?: string }> = [];
  const selected: Array<Record<string, unknown>> = [];
  const selectedByKey = new Map<string, Record<string, unknown>>();
  const seen = new Set<string>();

  // Keep network concurrency bounded so the public playlist hosts are not flooded.
  for (let start = 0; start < SOURCES.length; start += 6) {
    const group = SOURCES.slice(start, start + 6);
    const results = await Promise.all(group.map(async (source) => {
      try {
        const response = await fetch(source.url, {
          headers: { Accept: "application/x-mpegURL, audio/x-mpegurl, text/plain, */*" },
          signal: AbortSignal.timeout(10000),
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
      let duplicates = 0;
      for (const row of result.parsed) {
        const key = String(row.source_key ?? "");
        // Deduplicate within a category, while preserving cross-category memberships.
        if (!key) continue;
        if (seen.has(key)) {
          duplicates++;
          // Same channel/category may appear in multiple configured playlists with
          // different stream URLs. Keep every unique URL as an ordered playback mirror.
          const previous = selectedByKey.get(key);
          if (previous) {
            const previousMirrors = Array.isArray(previous.stream_urls)
              ? previous.stream_urls.filter((value): value is string => typeof value === "string" && value.length > 0)
              : [];
            const previousPrimary = typeof previous.url_stream === "string" ? previous.url_stream : "";
            const incomingUrl = typeof row.url_stream === "string" ? row.url_stream : "";
            previous.stream_urls = [...new Set([previousPrimary, ...previousMirrors, incomingUrl].filter(Boolean))];
          }
          continue;
        }
        seen.add(key);
        row.stream_urls = typeof row.url_stream === "string" ? [row.url_stream] : [];
        selected.push(row);
        selectedByKey.set(key, row);
        accepted++;
      }
      const rejected = Math.max(0, result.fetched - result.parsed.length);
      const sourceError = result.error ??
        (result.fetched === 0
          ? "La lista no contiene entradas #EXTINF."
          : result.parsed.length === 0
          ? "No contiene URLs HTTPS directas .m3u8 aceptables."
          : undefined);
      const sourceWarning = rejected > 0
        ? `${rejected} entradas filtradas; solo se aceptan entradas con título y URL HTTPS directa terminada en .m3u8.`
        : undefined;
      sourceResults.push({
        source: result.source.name,
        fetched: result.fetched,
        accepted,
        rejected,
        duplicates,
        ...(sourceError ? { error: sourceError } : {}),
        ...(sourceWarning ? { warning: sourceWarning } : {}),
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

  if (dryRun) {
    const failedSources = sourceResults.filter((source) => Boolean(source.error));
    return json({
      ok: failedSources.length === 0,
      dryRun: true,
      writePerformed: false,
      candidateChannels: selected.length,
      failedSources: failedSources.length,
      warningSources: sourceResults.filter((source) => Boolean(source.warning)).length,
      sources: sourceResults,
      note: "Read-only preflight: configured M3U sources were fetched and parsed, but no catalog rows or URLs were read or written. Entries not matching the strict HTTPS .m3u8 rule are reported as warnings and are not imported.",
    });
  }

  let imported = 0;
  for (let start = 0; start < selected.length; start += BATCH_SIZE) {
    const batch = selected.slice(start, start + BATCH_SIZE);
    const batchKeys = batch.map((row) => String(row.source_key ?? "")).filter(Boolean);
    const { data: existingRows, error: existingError } = await supabase
      .from("channels")
      .select("source_key,url_stream,stream_urls")
      .in("source_key", batchKeys);
    if (existingError) {
      return json({
        ok: false,
        imported,
        attempted: selected.length,
        sources: sourceResults,
        error: `No se pudieron leer las URLs existentes antes de sincronizar: ${existingError.message}`,
      }, 502);
    }

    for (const row of batch) {
      const key = String(row.source_key ?? "");
      const existing = (existingRows ?? []).find((candidate) => String(candidate.source_key) === key);
      const incomingPrimary = typeof row.url_stream === "string" ? row.url_stream : "";
      const incomingMirrors = Array.isArray(row.stream_urls)
        ? row.stream_urls.filter((value): value is string => typeof value === "string" && value.length > 0)
        : [];
      const existingPrimary = typeof existing?.url_stream === "string" ? existing.url_stream : "";
      const existingMirrors = Array.isArray(existing?.stream_urls)
        ? existing.stream_urls.filter((value): value is string => typeof value === "string" && value.length > 0)
        : [];
      // Prefer the current playlist URL, but retain the previous primary and all
      // previously stored mirrors so a resync cannot silently discard a URL.
      row.stream_urls = [...new Set([
        incomingPrimary, ...incomingMirrors, existingPrimary, ...existingMirrors,
      ].filter(Boolean))];
    }

    const { data, error } = await supabase
      .from("channels")
      .upsert(batch, { onConflict: "source_key" })
      .select("source_key");
    if (error) {
      return json({
        ok: false,
        imported,
        attempted: selected.length,
        sources: sourceResults,
        error: `Falló la importación por lotes: ${error.message}`,
      }, 502);
    }
    if (!data || data.length !== batch.length) {
      return json({
        ok: false,
        imported,
        attempted: selected.length,
        sources: sourceResults,
        error: `Verificación de escritura fallida: se esperaban ${batch.length} filas confirmadas y se recibieron ${data?.length ?? 0}.`,
      }, 502);
    }
    imported += data.length;
  }

  const failedSources = sourceResults.filter((source) => Boolean(source.error));
  const complete = failedSources.length === 0 && imported === selected.length;
  return json({
    ok: complete,
    complete,
    imported,
    failedSources: failedSources.length,
    warningSources: sourceResults.filter((source) => Boolean(source.warning)).length,
    sources: sourceResults,
    note: "Se importaron canales en vivo con URL HTTPS .m3u8 por lotes. Las entradas que pertenecen a varias categorías se almacenan como filas categorizadas separadas para conservar ambos filtros. Las fuentes de películas/series siguen siendo canales temáticos, no registros VOD. La importación no garantiza disponibilidad de cada emisión ni derechos de redistribución.",
  });
});
