#!/usr/bin/env python3
"""Read-only, paginated audit of the published MILTVPLUS-QA channel catalog."""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

PAGE_SIZE = 1000

def get_page(base_url, anon_key, offset):
    query = urllib.parse.urlencode({
        "select": "id,title,country_code,category,url_stream,stream_urls,is_published,source_key",
        "is_published": "eq.true",
        "order": "id.asc",
        "limit": str(PAGE_SIZE),
        "offset": str(offset),
    })
    req = urllib.request.Request(
        base_url.rstrip("/") + "/rest/v1/channels?" + query,
        headers={
            "apikey": anon_key,
            "Authorization": "Bearer " + anon_key,
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            if response.status != 200:
                raise RuntimeError(f"Supabase returned HTTP {response.status}")
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read(1000).decode("utf-8", "replace")
        raise RuntimeError(f"Supabase HTTP {exc.code}: {detail}") from exc
    if not isinstance(payload, list):
        raise RuntimeError("Unexpected Supabase response: expected a JSON array")
    return payload

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", default="qa-catalog-audit.json")
    args = parser.parse_args()
    anon_key = os.environ.get("SUPABASE_QA_ANON_KEY", "").strip()
    if not anon_key:
        raise SystemExit("SUPABASE_QA_ANON_KEY is missing.")
    if args.url.rstrip("/") != "https://uoqfovrynlyterjylpqj.supabase.co":
        raise SystemExit("Safety stop: audit target is not the hardcoded MILTVPLUS-QA URL.")

    rows = []
    offset = 0
    while True:
        page = get_page(args.url, anon_key, offset)
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            break
        offset += len(page)

    countries = Counter()
    categories = Counter()
    argentina_categories = Counter()
    title_keys = set()
    title_counts = Counter()
    rows_with_category_scoped_key = 0
    rows_with_legacy_m3u_key = 0
    rows_with_primary = 0
    rows_with_mirrors = 0
    rows_with_stream_urls_array = 0
    rows_missing_primary = 0
    rows_country_zz = 0
    rows_missing_country = 0
    url_hosts = Counter()
    for row in rows:
        country = str(row.get("country_code") or "").strip().upper()
        category = str(row.get("category") or "(sin categoría)").strip()
        title = str(row.get("title") or "").strip().casefold()
        if title:
            title_keys.add(title)
            title_counts[title] += 1
        source_key = str(row.get("source_key") or "")
        if source_key.startswith("m3u:") and ":category:" in source_key:
            rows_with_category_scoped_key += 1
        elif source_key.startswith("m3u:"):
            rows_with_legacy_m3u_key += 1
        countries[country or "(sin país)"] += 1
        categories[category] += 1
        if country == "AR":
            argentina_categories[category] += 1
        if country == "ZZ":
            rows_country_zz += 1
        if not country:
            rows_missing_country += 1
        primary = str(row.get("url_stream") or "").strip()
        if primary.startswith(("https://", "http://")):
            rows_with_primary += 1
            host = urllib.parse.urlparse(primary).hostname or "(host inválido)"
            url_hosts[host] += 1
        else:
            rows_missing_primary += 1
        mirrors = row.get("stream_urls")
        valid_mirrors = [
            value.strip() for value in mirrors
            if isinstance(mirrors, list) and isinstance(value, str)
            and value.strip().startswith(("https://", "http://"))
        ] if isinstance(mirrors, list) else []
        if valid_mirrors:
            rows_with_stream_urls_array += 1
        if any(value != primary for value in valid_mirrors):
            rows_with_mirrors += 1

    report = {
        "target": "MILTVPLUS-QA (read only)",
        "total_rows": len(rows),
        "unique_titles": len(title_keys),
        "rows_with_repeated_title": sum(count for count in title_counts.values() if count > 1),
        "distinct_titles_repeated": sum(1 for count in title_counts.values() if count > 1),
        "rows_with_category_scoped_key": rows_with_category_scoped_key,
        "rows_with_legacy_m3u_key": rows_with_legacy_m3u_key,
        "rows_with_primary_url": rows_with_primary,
        "rows_with_stream_urls_array": rows_with_stream_urls_array,
        "rows_with_mirrors": rows_with_mirrors,
        "rows_missing_primary_url": rows_missing_primary,
        "rows_country_zz": rows_country_zz,
        "rows_missing_country_code": rows_missing_country,
        "countries": dict(sorted(countries.items())),
        "categories": dict(sorted(categories.items())),
        "argentina_categories": dict(sorted(argentina_categories.items())),
        "top_stream_hosts": dict(url_hosts.most_common(25)),
        "audit_limitations": [
            "Counts describe published database rows, not all channels that exist worldwide.",
            "HTTP(S) URL presence does not prove endpoint reachability or actual playback.",
            "Completeness requires comparison with a defined authoritative source list.",
        ],
    }
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in (
        "target", "total_rows", "unique_titles", "rows_with_repeated_title",
        "distinct_titles_repeated", "rows_with_category_scoped_key", "rows_with_legacy_m3u_key", "rows_with_primary_url",
        "rows_with_stream_urls_array", "rows_with_mirrors", "rows_missing_primary_url", "rows_country_zz",
        "rows_missing_country_code", "argentina_categories", "countries", "categories"
    )}, ensure_ascii=False, indent=2))
    print(f"Full report written to {args.output}")
    if not rows:
        raise SystemExit("Audit returned zero published channels; check QA RLS/catalog before proceeding.")

if __name__ == "__main__":
    main()
