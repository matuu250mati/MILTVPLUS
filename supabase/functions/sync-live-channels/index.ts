// Import authorized live-TV channels from an owner-configured M3U source.
// Required Supabase secrets: CHANNELS_M3U_URL (HTTPS M3U URL) and SYNC_SECRET.
// Uses service_role only server-side. Never pass provider credentials from client requests.
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

type Channel = {
  title: string;
  synopsis: string;
  category: string;
  logo: string | null;
  url_stream: string;
  stream_format: "hls" | "m3u8";
  country_code: string;
  sort_order: number;
  is_published: boolean;
};

function attributes(extinf: string): Record<string, string> {
  const found: Record<string, string> = {};
  for (const match of extinf.matchAll(/([\w-]+)="([^"]*)"/g)) {
    found[match[1].toLowerCase()] = match[2].trim();
  }
  return found;
}

function safeHttpsUrl(value: string): string | null {
  try {
    const url = new URL(value.trim());
    if (url.protocol !== "https:" || url.username || url.password) return null;
    return url.toString();
  } catch {
    return null;
  }
}

function parseM3u(input: string): Channel[] {
  const lines = input.replace(/^\uFEFF/, "").split(/\r?\n/);
  const result = new Map<string, Channel>();
  let pending: { title: string; logo: string | null; category: string; country: string } | null = null;

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith("#EXTINF:")) {
      const comma = line.indexOf(",");
      const attrs = attributes(line);
      const title = (comma >= 0 ? line.slice(comma + 1).trim() : "") ||
        attrs["tvg-name"] || "Canal sin nombre";
      const group = attrs["group-title"] || "Otros canales";
      const logo = attrs["tvg-logo"] ? safeHttpsUrl(attrs["tvg-logo"]) : null;
      const country = (attrs["tvg-country"] || attrs["tvg-language"] || "").toUpperCase();
      pending = {
        title: title.slice(0, 180),
        logo,
        category: group.slice(0, 80),
        country: country.includes("AR") || country.includes("ARG") ? "AR" : "AR",
      };
      continue;
    }
    if (line.startsWith("#")) continue;
    if (!pending) continue;

    const stream = safeHttpsUrl(line);
    if (stream && /\.m3u8(?:$|[?#])/i.test(new URL(stream).pathname + new URL(stream).search)) {
      result.set(stream, {
        title: pending.title,
        synopsis: "",
        category: pending.category,
        logo: pending.logo,
        url_stream: stream,
        stream_format: "m3u8",
        country_code: pending.country,
        sort_order: result.size,
        is_published: true,
      });
    }
    pending = null;
    if (result.size >= 500) break;
  }
  return [...result.values()];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const expectedSecret = Deno.env.get("SYNC_SECRET");
  const suppliedSecret = req.headers.get("x-sync-secret");
  if (!expectedSecret || !suppliedSecret || suppliedSecret !== expectedSecret) {
    return json({ error: "Unauthorized live-channel sync request." }, 401);
  }

  const sourceValue = Deno.env.get("CHANNELS_M3U_URL");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!sourceValue || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "Missing CHANNELS_M3U_URL or Supabase server secrets." }, 500);
  }

  // Source is configured by the project owner, never supplied by an untrusted caller.
  const source = safeHttpsUrl(sourceValue);
  if (!source) return json({ error: "CHANNELS_M3U_URL must be an HTTPS URL without embedded credentials." }, 500);

  try {
    const response = await fetch(source, {
      headers: { Accept: "application/x-mpegURL, application/vnd.apple.mpegurl, text/plain" },
      signal: AbortSignal.timeout(15000),
      redirect: "error",
    });
    if (!response.ok) return json({ error: `M3U source returned HTTP ${response.status}.` }, 502);
    const declaredLength = Number(response.headers.get("content-length") || 0);
    if (declaredLength > 5 * 1024 * 1024) return json({ error: "M3U source exceeds 5 MiB." }, 413);
    const body = await response.text();
    if (new TextEncoder().encode(body).byteLength > 5 * 1024 * 1024) {
      return json({ error: "M3U source exceeds 5 MiB." }, 413);
    }
    if (!body.trimStart().startsWith("#EXTM3U")) return json({ error: "Configured source is not an M3U playlist." }, 422);

    const channels = parseM3u(body);
    if (!channels.length) return json({ error: "No HTTPS .m3u8 streams found; existing channel rows were left unchanged." }, 422);

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Update matching URLs by primary key; insert new URLs. Do not delete rows absent
    // from a feed, because a transient/incomplete playlist must not wipe the catalog.
    const urls = channels.map((channel) => channel.url_stream);
    const { data: existing, error: lookupError } = await supabase
      .from("channels")
      .select("id,url_stream")
      .in("url_stream", urls);
    if (lookupError) throw new Error(`Supabase channel lookup failed: ${lookupError.message}`);

    const idsByUrl = new Map<string, string>((existing ?? []).map((row: { id: string; url_stream: string }) => [row.url_stream, row.id]));
    let inserted = 0;
    let updated = 0;
    for (const channel of channels) {
      const id = idsByUrl.get(channel.url_stream);
      const result = id
        ? await supabase.from("channels").update({ ...channel, updated_at: new Date().toISOString() }).eq("id", id)
        : await supabase.from("channels").insert(channel);
      if (result.error) throw new Error(`Supabase channel write failed: ${result.error.message}`);
      if (id) updated++;
      else inserted++;
    }

    return json({
      ok: true,
      source: "configured M3U",
      parsed: channels.length,
      inserted,
      updated,
      note: "Only HTTPS HLS entries were imported. Review distribution rights and test playback on the target device.",
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Live channel sync failed." }, 502);
  }
});
