#!/usr/bin/env node
// Imports films from Internet Archive that carry an open licence (public-domain mark,
// CC0, CC BY, CC BY-SA) into the MILTVPLUS "movies" table, with a direct MP4 URL that
// plays inside the app's native player.
//
// Safety rules:
//  - An item is imported only if its metadata `licenseurl` is on the allowlist below, or
//    its identifier is listed in --ids-file (a list the catalog owner verified by hand).
//  - Nothing is scraped from third-party sites; every URL comes from archive.org itself.
//  - Default mode is a dry run that only writes a manifest. Use --apply to write to Supabase.
//  - Existing stream URLs are never overwritten.
//
// Usage:
//   node tool/import_archive_catalog.mjs --limit 25 --out manifest.json
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... TMDB_API_KEY=... \
//     node tool/import_archive_catalog.mjs --limit 25 --apply

import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const CATEGORY = 'Cine gratis (dominio público)';
const IA = 'https://archive.org';
const OPEN_LICENSE =
  /^https?:\/\/creativecommons\.org\/(publicdomain\/(mark|zero)\/1\.0|licenses\/(by|by-sa)\/[0-9.]+)\/?/i;

export const isOpenLicense = (url) => typeof url === 'string' && OPEN_LICENSE.test(url.trim());

const asArray = (value) => (Array.isArray(value) ? value : value == null ? [] : [value]);
const text = (value) => asArray(value).join(' ').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

export function parseYear(value) {
  const match = String(asArray(value)[0] ?? '').match(/(1[89]\d\d|20\d\d)/);
  return match ? Number(match[1]) : null;
}

/** Picks the best directly playable MP4 and any other MP4 files as mirrors. */
export function pickVideoFiles(files) {
  const mp4s = (files ?? [])
    .filter((file) => /\.mp4$/i.test(file.name ?? ''))
    .filter((file) => !/trailer|sample|preview/i.test(file.name))
    .filter((file) => Number(file.size ?? 0) > 20 * 1024 * 1024)
    .sort((a, b) => {
      const rank = (file) => (/h\.?264/i.test(file.format ?? '') ? 0 : /mpeg4/i.test(file.format ?? '') ? 1 : 2);
      return rank(a) - rank(b) || Number(b.size ?? 0) - Number(a.size ?? 0);
    });
  return mp4s;
}

export const downloadUrl = (identifier, fileName) =>
  `${IA}/download/${encodeURIComponent(identifier)}/${fileName.split('/').map(encodeURIComponent).join('/')}`;

export function buildMovieRow({ identifier, metadata, files, tmdb }) {
  const videos = pickVideoFiles(files);
  if (!videos.length) return null;
  const urls = videos.slice(0, 3).map((file) => downloadUrl(identifier, file.name));
  const title = text(metadata.title) || identifier;
  const seconds = Math.round(Number(videos[0].length ?? 0)) || null;
  const genres = ['Gratis', 'Dominio público', ...asArray(metadata.subject).map(String).slice(0, 2)];
  return {
    tmdb_id: tmdb?.id ?? null,
    title: tmdb?.title || title,
    synopsis: tmdb?.overview || text(metadata.description).slice(0, 900),
    category: CATEGORY,
    genres,
    logo: tmdb?.poster_path ? `https://image.tmdb.org/t/p/w500${tmdb.poster_path}` : `${IA}/services/img/${identifier}`,
    backdrop_url: tmdb?.backdrop_path ? `https://image.tmdb.org/t/p/w1280${tmdb.backdrop_path}` : null,
    url_stream: urls[0],
    stream_urls: urls,
    release_year: parseYear(metadata.year ?? metadata.date),
    duration_seconds: seconds,
    country_code: 'AR',
    is_published: true,
    _source: { identifier, licenseurl: metadata.licenseurl ?? null, page: `${IA}/details/${identifier}` },
  };
}

async function getJson(url, headers = {}) {
  const response = await fetch(url, { headers: { Accept: 'application/json', ...headers } });
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url.split('?')[0]}`);
  return response.json();
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function searchIdentifiers(limit) {
  const query = 'collection:(feature_films) AND mediatype:(movies)';
  const url = `${IA}/advancedsearch.php?q=${encodeURIComponent(query)}&fl[]=identifier&sort[]=downloads+desc&rows=${limit * 6}&page=1&output=json`;
  const data = await getJson(url);
  return (data.response?.docs ?? []).map((doc) => doc.identifier);
}

async function matchTmdb(apiKey, title, year) {
  if (!apiKey) return null;
  const url = new URL('https://api.themoviedb.org/3/search/movie');
  url.searchParams.set('api_key', apiKey);
  url.searchParams.set('language', 'es-ES');
  url.searchParams.set('query', title);
  if (year) url.searchParams.set('year', String(year));
  const data = await getJson(url.toString());
  const hit = (data.results ?? [])[0];
  if (!hit) return null;
  const hitYear = parseYear(hit.release_date);
  if (year && hitYear && Math.abs(hitYear - year) > 1) return null;
  return hit;
}

async function applyRows(rows, { url, key }) {
  const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
  const stats = { inserted: 0, updated: 0, skipped: 0 };
  for (const row of rows) {
    const { _source, ...payload } = row;
    const filters = payload.tmdb_id
      ? `tmdb_id=eq.${payload.tmdb_id}`
      : `title=eq.${encodeURIComponent(payload.title)}&release_year=${payload.release_year ? `eq.${payload.release_year}` : 'is.null'}`;
    const lookup = await fetch(`${url}/rest/v1/movies?select=id,url_stream&${filters}`, { headers });
    if (!lookup.ok) throw new Error(`Lookup failed (${lookup.status}): ${await lookup.text()}`);
    const existing = (await lookup.json())[0];
    if (existing) {
      if ((existing.url_stream ?? '').trim()) { stats.skipped++; continue; }
      const patch = await fetch(`${url}/rest/v1/movies?id=eq.${existing.id}`, {
        method: 'PATCH', headers, body: JSON.stringify({ url_stream: payload.url_stream, stream_urls: payload.stream_urls }),
      });
      if (!patch.ok) throw new Error(`Update failed (${patch.status}): ${await patch.text()}`);
      stats.updated++;
    } else {
      const insert = await fetch(`${url}/rest/v1/movies`, { method: 'POST', headers, body: JSON.stringify(payload) });
      if (!insert.ok) throw new Error(`Insert failed (${insert.status}): ${await insert.text()}`);
      stats.inserted++;
    }
  }
  return stats;
}

export function parseArgs(argv) {
  const args = { limit: 25, out: 'archive_manifest.json', apply: false, idsFile: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--limit') args.limit = Math.max(1, Math.min(Number(argv[++i]) || 25, 100));
    else if (argv[i] === '--out') args.out = argv[++i];
    else if (argv[i] === '--ids-file') args.idsFile = argv[++i];
    else if (argv[i] === '--apply') args.apply = true;
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const tmdbKey = process.env.TMDB_API_KEY;
  const curated = new Set();
  if (args.idsFile) {
    for (const line of (await readFile(args.idsFile, 'utf8')).split('\n')) {
      const id = line.replace(/#.*/, '').trim();
      if (id) curated.add(id);
    }
  }
  const identifiers = [...curated, ...(await searchIdentifiers(args.limit))];
  const rows = [];
  const report = { checked: 0, rejectedLicense: 0, noVideo: 0 };
  for (const identifier of [...new Set(identifiers)]) {
    if (rows.length >= args.limit) break;
    report.checked++;
    try {
      const data = await getJson(`${IA}/metadata/${encodeURIComponent(identifier)}`);
      const metadata = data.metadata ?? {};
      if (!curated.has(identifier) && !isOpenLicense(asArray(metadata.licenseurl)[0])) { report.rejectedLicense++; continue; }
      const title = text(metadata.title);
      const tmdb = await matchTmdb(tmdbKey, title, parseYear(metadata.year ?? metadata.date)).catch(() => null);
      const row = buildMovieRow({ identifier, metadata: { ...metadata, licenseurl: asArray(metadata.licenseurl)[0] }, files: data.files, tmdb });
      if (!row) { report.noVideo++; continue; }
      rows.push(row);
    } catch (error) {
      console.error(`skip ${identifier}: ${error.message}`);
    }
    await sleep(400);
  }
  await writeFile(args.out, JSON.stringify({ report, rows }, null, 2));
  console.log(`Prepared ${rows.length} films (${JSON.stringify(report)}). Manifest: ${args.out}`);
  if (!args.apply) { console.log('Dry run: nothing was written to Supabase.'); return; }
  const url = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required with --apply.');
  console.log('Applied:', JSON.stringify(await applyRows(rows, { url, key })));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => { console.error(error.message); process.exit(1); });
}
