#!/usr/bin/env python3
"""Read-only, rate-limited sample probe of published MILTVPLUS-QA stream URLs.

This checks HTTP reachability and whether a response resembles an HLS manifest.
It does not prove sustained playback. URLs, titles, query strings and tokens are
never written to the report or logs.
"""
import concurrent.futures
import json
import os
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

QA_URL = "https://uoqfovrynlyterjylpqj.supabase.co"
PAGE_SIZE = 1000
MAX_SAMPLES = 180
MAX_PER_HOST = 3
TIMEOUT_SECONDS = 8
READ_BYTES = 4096


def get_page(anon_key, offset):
    query = urllib.parse.urlencode({
        "select": "id,country_code,category,url_stream,is_published",
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


def safe_candidate(row):
    raw = str(row.get("url_stream") or "").strip()
    try:
        parsed = urllib.parse.urlsplit(raw)
        if parsed.scheme.lower() not in ("http", "https") or not parsed.hostname:
            return None
        if parsed.username or parsed.password:
            return None
        return {
            "url": raw,
            "host": parsed.hostname.lower(),
            "scheme": parsed.scheme.lower(),
            "country": str(row.get("country_code") or "ZZ").upper(),
            "category": str(row.get("category") or "(sin categoría)").strip(),
        }
    except Exception:
        return None


def choose_sample(rows):
    by_category = defaultdict(list)
    by_country = defaultdict(list)
    for row in rows:
        candidate = safe_candidate(row)
        if candidate:
            by_category[candidate["category"]].append(candidate)
            by_country[candidate["country"]].append(candidate)

    ordered = []
    seen_urls = set()
    # Stratify across genres first, then countries so large countries do not
    # consume the entire sample. Stable database ordering makes runs comparable.
    for bucket, limit in [(by_category, 2), (by_country, 1)]:
        for key in sorted(bucket):
            added = 0
            for item in bucket[key]:
                if item["url"] in seen_urls:
                    continue
                seen_urls.add(item["url"])
                ordered.append(item)
                added += 1
                if added >= limit:
                    break

    result = []
    host_counts = Counter()
    for item in ordered:
        if host_counts[item["host"]] >= MAX_PER_HOST:
            continue
        result.append(item)
        host_counts[item["host"]] += 1
        if len(result) >= MAX_SAMPLES:
            break
    return result


def probe(item):
    req = urllib.request.Request(
        item["url"],
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
            return {
                "country": item["country"], "category": item["category"],
                "host": item["host"], "scheme": item["scheme"],
                "http_status": status, "result": result,
                "content_type": content_type[:80],
            }
    except urllib.error.HTTPError as exc:
        return {"country": item["country"], "category": item["category"],
                "host": item["host"], "scheme": item["scheme"],
                "http_status": exc.code,
                "result": "http_4xx" if 400 <= exc.code < 500 else "http_5xx",
                "content_type": exc.headers.get("Content-Type", "").lower().split(";")[0][:80]}
    except (TimeoutError, socket.timeout):
        return {"country": item["country"], "category": item["category"],
                "host": item["host"], "scheme": item["scheme"],
                "http_status": None, "result": "timeout", "content_type": ""}
    except urllib.error.URLError as exc:
        reason = str(getattr(exc, "reason", "")).lower()
        result = "timeout" if "timed out" in reason or "timeout" in reason else (
            "tls_error" if "ssl" in reason or "certificate" in reason else "connection_error"
        )
        return {"country": item["country"], "category": item["category"],
                "host": item["host"], "scheme": item["scheme"],
                "http_status": None, "result": result, "content_type": ""}
    except Exception as exc:
        reason = str(exc).lower()
        result = "timeout" if "timed out" in reason or "timeout" in reason else "other_error"
        return {"country": item["country"], "category": item["category"],
                "host": item["host"], "scheme": item["scheme"],
                "http_status": None, "result": result, "content_type": ""}


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
    counts = Counter(item["result"] for item in results)
    by_category = defaultdict(Counter)
    by_country = defaultdict(Counter)
    for item in results:
        by_category[item["category"]][item["result"]] += 1
        by_country[item["country"]][item["result"]] += 1
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
        },
        "result_counts": dict(sorted(counts.items())),
        "by_country": {k: dict(sorted(v.items())) for k, v in sorted(by_country.items())},
        "by_category": {k: dict(sorted(v.items())) for k, v in sorted(by_category.items())},
        "samples": results,
        "limitations": [
            "A successful HTTP response or HLS manifest does not prove sustained video playback.",
            "Only a stratified sample is probed; untested rows remain unverified.",
            "Some providers require headers, tokens, geographic access, or player-specific handling.",
            "Stream URLs and query tokens are intentionally excluded from the report.",
        ],
    }
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "target": report["target"],
        "published_rows_seen": len(rows),
        "sample_size": len(results),
        "result_counts": report["result_counts"],
        "http_2xx_total": counts["hls_manifest"] + counts["http_2xx_non_hls"],
        "hls_manifest_total": counts["hls_manifest"],
        "http_errors_total": sum(v for k, v in counts.items() if k.startswith("http_")),
        "timeouts": counts["timeout"],
        "tls_errors": counts["tls_error"],
        "report_file": args.output,
    }, ensure_ascii=False, indent=2))
    if not results:
        raise SystemExit("No stream URLs could be selected for the read-only probe.")


if __name__ == "__main__":
    main()
