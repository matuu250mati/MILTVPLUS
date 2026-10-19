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
