# QA M3U stream mirror validation

This branch preserves each channel's primary URL and ordered alternatives in `stream_urls`.

## Safety boundaries
- HTTP and HTTPS stream candidates are retained exactly as supplied (apart from URL parsing/serialization); credentials embedded in URLs and local hosts are rejected.
- The Android app continues to keep cleartext traffic disabled. HTTP mirrors remain catalog data, but the Android/iOS/web player skips them and tries later secure mirrors.
- HLS, DASH, extensionless endpoints, and other HTTP(S) candidates are not declared playable just because they were imported.
- The read-only QA preflight may fetch and parse the configured public playlists, but it does not write catalog rows. Database import uses 100-row batches to keep URL lookups within request-size limits.
- The `channels.stream_urls` migration must be applied to MILTVPLUS-QA and schema-verified before a live sync is authorized.
- Production project, production database, and production app remain out of scope.

## Evidence required before calling the catalog complete
1. Flutter tests and Android QA build pass on the final commit.
2. QA-only edge-function preflight reports all source fetches and candidate counts.
3. The QA migration is applied and `channels.stream_urls` is verified.
4. A confirmed QA sync returns the exact imported row count and a subsequent read-back confirms primary and mirror URLs were retained.
5. URL reachability, valid manifest, and actual playback are reported as separate outcomes.
6. The signed QA APK is tested on a physical Android phone and the user's TCL Android TV.

No step may be reported complete without its corresponding result.

## QA country metadata inference (2026-10-19)

The QA sync function may infer a missing country code only when an exact `tvg-id` matches an entry from a country-specific configured playlist. It does not infer from names or stream URLs, and leaves ambiguous matches as `ZZ`. Deploying this change runs a read-only source preflight only; it does not write catalog rows. Production is not a deployment target.

The country-inference code passed the Deno type-check and the updated Edge Function was deployed to MILTVPLUS-QA. The deployment's source preflight completed as a dry run with `writePerformed=false`; this documentation commit authorizes the separate QA-only catalog sync workflow to apply the reviewed inference. No production target is configured.

## Read-only stream reachability sample

The gated QA workflow `Read-only MILTVPLUS-QA stream reachability probe` samples up to 180 published stream URLs with low concurrency and short timeouts. It records only host, country/category, HTTP status, and response classification; it never writes catalog data or reports full URLs/tokens. A reachable HLS manifest is not treated as proof of sustained playback.

## Cross-category playback mirror QA deployment

The sync function now shares alternate stream URLs only between rows with an exact matching `tvg-id`, while retaining category-specific rows and existing stored URLs. Deploy via the QA-only gated workflow and require the read-only source preflight to pass before running the separate QA catalog sync. Production is not a target.

The QA deployment of cross-category `tvg-id` mirror sharing completed successfully, and its read-only preflight passed for all 42 configured sources. Run the separate QA-only catalog sync to update `stream_urls`; the workflow verifies imported row counts and never targets production.

Post-sync verification is performed by the read-only catalog audit after the live QA sync completes; the earlier audit run may overlap the write and must not be treated as post-sync mirror counts.

The post-sync stream probe now tries up to two stored alternate URLs only when a sampled primary URL does not return an HLS manifest. It records whether an alternate gives an HLS or other HTTP 2xx response, without logging stream URLs or tokens.

## Country metadata enrichment

When a channel still has `ZZ` after configured country playlists and exact `tvg-id` matches, the QA sync may consult IPTV-org's public channel metadata by exact channel ID. This lookup is optional and read-only; if it fails or returns ambiguous countries, the sync continues and leaves the country unknown rather than guessing. Deployment runs the read-only source preflight before any separate catalog write.

The optional IPTV-org country metadata enrichment deployed to MILTVPLUS-QA and its 42-source dry-run passed with `writePerformed=false`. The next QA-only sync applies exact-ID country enrichment; unknown/ambiguous values remain `ZZ`, and production remains untouched.

After the metadata-enriched QA sync completed, rerun the read-only catalog audit and the mirror-prioritized stream probe against the final QA rows. This post-sync check must be kept separate from any concurrent write.

The latest QA APK workflow passed Flutter analysis/tests, QA Supabase URL/DNS/HTTPS, required-schema checks, and Android TV manifest validation. The release APK build step remained active unusually long, so a fresh QA-only build run is being requested; this does not alter app code or production.
