#!/usr/bin/env python3
"""Read-only, rate-limited sample probe of published MILTVPLUS-QA stream URLs.

Checks primary URL reachability and tries up to two stored alternate URLs only
when the primary does not return an HLS manifest. This is not a playback test.
Full URLs, query strings, credentials and token-bearing paths are never logged.
"""
import concurrent.futures
import json
import os
import socket
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

QA_URL = "https://uoqfovrynlyterjylpqj.supabase.co"
PAGE_SIZE = 1000
MAX_SAMPLES = 180
MAX_PER_HOST = 3
MAX_ALTERNATES_PER_ROW = 2
TIMEOUT_SECONDS = 8
READ_BYTES = 4096


def get_page(anon_key, offset):
    query = urllib.parse.urlencode({
        "select": "id,title,country_code,category,url_stream,stream_urls,is_published",
        "is_published": "eq.true",
        "order": "id.asc",
        "limit": str(PAGE_SIZE),
        "offset": str(offset),
    })
    req = urllib.request.Request(
        QA_URL + "/rest/v1/channels?" + query,
        headers={"apikey": anon_key, "Authorization": "Bearer " + anon_key,
                 "Accept": "application/json"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, list):
        raise RuntimeError("Unexpected Supabase response; expected a JSON array")
    return payload


def safe_url(value):
    raw = str(value or "").strip()
    try:
        parsed = urllib.parse.urlsplit(raw)
        if parsed.scheme.lower() not in ("http", "https") or not parsed.hostname:
            return None
        if parsed.username or parsed.password:
            return None
        return {"url": raw, "host": parsed.hostname.lower(), "scheme": parsed.scheme.lower()}
    except Exception:
        return None


def safe_candidate(row):
    urls = []
    for raw in [row.get("url_stream"), *(row.get("stream_urls") if isinstance(row.get("stream_urls"), list) else [])]:
        candidate = safe_url(raw)
        if candidate and all(existing["url"] != candidate["url"] for existing in urls):
            urls.append(candidate)
    if not urls:
        return None
    primary_raw = str(row.get("url_stream") or "").strip()
    primary_index = next((i for i, item in enumerate(urls) if item["url"] == primary_raw), 0)
    primary = urls.pop(primary_index)
    return {
        "channel_id": str(row.get("id") or ""),
        "title": str(row.get("title") or "(sin título)"),
        "country": str(row.get("country_code") or "ZZ").upper(),
        "category": str(row.get("category") or "(sin categoría)").strip(),
        "url": primary["url"],
        "host": primary["host"],
        "scheme": primary["scheme"],
        "alternate_urls": urls,
    }


def choose_sample(rows):
    by_category = defaultdict(list)
    by_country = defaultdict(list)
    all_candidates = []
    for row in rows:
        candidate = safe_candidate(row)
        if candidate:
            all_candidates.append(candidate)
            by_category[candidate["category"]].append(candidate)
            by_country[candidate["country"]].append(candidate)

    ordered = []
    seen_urls = set()
    # Prioritize rows that actually have alternate URLs so the fallback path is
    # exercised, then fill the remaining budget with a category/country sample.
    for item in all_candidates:
        if not item["alternate_urls"]:
            continue
        if item["url"] not in seen_urls:
            seen_urls.add(item["url"])
            ordered.append(item)

    stratified = []
    stratified_urls = set(seen_urls)
    for bucket, limit in [(by_category, 2), (by_country, 1)]:
        for key in sorted(bucket):
            added = 0
            for item in bucket[key]:
                if item["url"] in stratified_urls:
                    continue
                stratified_urls.add(item["url"])
                stratified.append(item)
                added += 1
                if added >= limit:
                    break
    ordered.extend(stratified)

    result = []
    host_counts = Counter()
    result_urls = set()
    # A host cap avoids hammering a single provider. Alternate-bearing rows are
    # considered first; the remaining slots stay stratified across categories.
    for item in ordered:
        if item["url"] in result_urls or host_counts[item["host"]] >= MAX_PER_HOST:
            continue
        result.append(item)
        result_urls.add(item["url"])
        host_counts[item["host"]] += 1
        if len(result) >= MAX_SAMPLES:
            break
    return result


def probe_url(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "MILTVPLUS-QA-ReadOnly-StreamProbe/1.0",
            "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, */*",
            "Range": f"bytes=0-{READ_BYTES - 1}",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as response:
            body = response.read(READ_BYTES)
            status = int(response.status)
            content_type = response.headers.get("Content-Type", "").lower().split(";")[0]
            is_manifest = body.lstrip().startswith(b"#EXTM3U") or "mpegurl" in content_type
            result = "hls_manifest" if 200 <= status < 300 and is_manifest else (
                "http_2xx_non_hls" if 200 <= status < 300 else "http_non_2xx"
            )
            return {"http_status": status, "result": result, "content_type": content_type[:80]}
    except urllib.error.HTTPError as exc:
        return {"http_status": exc.code,
                "result": "http_4xx" if 400 <= exc.code < 500 else "http_5xx",
                "content_type": exc.headers.get("Content-Type", "").lower().split(";")[0][:80]}
    except (TimeoutError, socket.timeout):
        return {"http_status": None, "result": "timeout", "content_type": ""}
    except urllib.error.URLError as exc:
        reason = str(getattr(exc, "reason", "")).lower()
        result = "timeout" if "timed out" in reason or "timeout" in reason else (
            "tls_error" if "ssl" in reason or "certificate" in reason else "connection_error"
        )
        return {"http_status": None, "result": result, "content_type": ""}
    except Exception as exc:
        reason = str(exc).lower()
        result = "timeout" if "timed out" in reason or "timeout" in reason else "other_error"
        return {"http_status": None, "result": result, "content_type": ""}


def probe(item):
    primary = probe_url(item["url"])
    alternate_results = []
    # If the primary is not an HLS manifest, try at most two stored alternates.
    # Stop at the first HLS manifest; never log any URL or query string.
    if primary["result"] != "hls_manifest":
        for alternate in item["alternate_urls"][:MAX_ALTERNATES_PER_ROW]:
            result = probe_url(alternate["url"])
            alternate_results.append({
                "host": alternate["host"],
                "scheme": alternate["scheme"],
                "http_status": result["http_status"],
                "result": result["result"],
                "content_type": result["content_type"],
            })
            if result["result"] == "hls_manifest":
                break

    fallback_success = next(
        (r for r in alternate_results if r["result"] in ("hls_manifest", "http_2xx_non_hls")),
        None,
    )
    return {
        "channel_id": item["channel_id"],
        "title": item["title"],
        "country": item["country"],
        "category": item["category"],
        "primary_host": item["host"],
        "primary_scheme": item["scheme"],
        "primary_http_status": primary["http_status"],
        "primary_result": primary["result"],
        "stored_alternate_count": len(item["alternate_urls"]),
        "alternate_attempts": len(alternate_results),
        "alternate_results": alternate_results,
        "fallback_success": fallback_success is not None,
        "fallback_host": fallback_success["host"] if fallback_success else None,
        "fallback_result": fallback_success["result"] if fallback_success else None,
    }


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="qa-stream-probe.json")
    args = parser.parse_args()
    anon_key = os.environ.get("SUPABASE_QA_ANON_KEY", "").strip()
    if not anon_key:
        raise SystemExit("SUPABASE_QA_ANON_KEY is missing.")

    rows = []
    offset = 0
    while True:
        page = get_page(anon_key, offset)
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            break
        offset += len(page)

    sample = choose_sample(rows)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(probe, sample))

    primary_counts = Counter(item["primary_result"] for item in results)
    fallback_attempted = sum(item["alternate_attempts"] > 0 for item in results)
    fallback_successes = sum(item["fallback_success"] for item in results)
    alternate_result_counts = Counter(
        result["result"] for item in results for result in item["alternate_results"]
    )
    by_category = defaultdict(Counter)
    by_country = defaultdict(Counter)
    for item in results:
        by_category[item["category"]][item["primary_result"]] += 1
        by_country[item["country"]][item["primary_result"]] += 1

    report = {
        "target": "MILTVPLUS-QA (read-only)",
        "published_rows_seen": len(rows),
        "sample_size": len(results),
        "sample_policy": {
            "up_to_two_per_category_then_one_per_country": True,
            "max_samples": MAX_SAMPLES,
            "max_per_host": MAX_PER_HOST,
            "parallel_requests": 4,
            "timeout_seconds": TIMEOUT_SECONDS,
            "response_bytes_read": READ_BYTES,
            "alternate_urls_tried_only_if_primary_not_hls": True,
            "max_alternates_per_row": MAX_ALTERNATES_PER_ROW,
        },
        "primary_result_counts": dict(sorted(primary_counts.items())),
        "alternate_result_counts": dict(sorted(alternate_result_counts.items())),
        "rows_with_alternate_attempts": fallback_attempted,
        "rows_where_alternate_returned_hls_or_http_2xx": fallback_successes,
        "by_country": {k: dict(sorted(v.items())) for k, v in sorted(by_country.items())},
        "by_category": {k: dict(sorted(v.items())) for k, v in sorted(by_category.items())},
        "samples": results,
        "limitations": [
            "An HTTP response or HLS manifest does not prove sustained video playback.",
            "Only a stratified sample is probed; untested rows remain unverified.",
            "Some providers require headers, tokens, geographic access, or player-specific handling.",
            "Full stream URLs, query strings, credentials and token-bearing paths are intentionally omitted.",
        ],
    }
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "target": report["target"],
        "published_rows_seen": len(rows),
        "sample_size": len(results),
        "primary_result_counts": report["primary_result_counts"],
        "alternate_result_counts": report["alternate_result_counts"],
        "rows_with_alternate_attempts": fallback_attempted,
        "rows_where_alternate_returned_hls_or_http_2xx": fallback_successes,
        "report_file": args.output,
    }, ensure_ascii=False, indent=2))
    if not results:
        raise SystemExit("No stream URLs could be selected for the read-only probe.")


if __name__ == "__main__":
    main()
