#!/usr/bin/env python3
"""Validate public M3U endpoints for MILTVPLUS QA. HTTP success is not proof of playback."""
import concurrent.futures
import csv
import json
import os
import re
import time
import urllib.error
import urllib.request
from collections import Counter
from urllib.parse import urlparse

PLAYLIST = os.environ.get("MILTVPLUS_M3U", "assets/catalog/iptv.m3u")
OUT = os.environ.get("MILTVPLUS_REPORT_DIR", "build/source-validation")
TIMEOUT = 4
WORKERS = 64
UA = "MILTVPLUS-QA-Source-Validator/1.0"

def parse_playlist(path):
    rows, info = [], None
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if line.startswith("#EXTINF"):
                info = line
            elif line and not line.startswith("#") and info:
                title = info.rsplit(",", 1)[-1].strip() or "Canal sin nombre"
                group = re.search(r'group-title="([^"]*)"', info)
                rows.append({"title": title, "category": group.group(1) if group else "",
                             "url": line, "status": "pending", "http_status": "",
                             "content_type": "", "detail": ""})
                info = None
    return rows

def check(row):
    url = row["url"]
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        row.update(status="invalid_url", detail="URL inválida")
        return row
    # Avoid printing URLs containing userinfo, query tokens, or signed credentials.
    safe_host = parsed.hostname
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Range": "bytes=0-262143"}, method="GET")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            is_hls = parsed.path.lower().endswith((".m3u8", ".m3u")) or "mpegurl" in content_type.lower()
            # Read only a tiny sample for media URLs; do not download stream segments.
            data = response.read(8192 if is_hls else 1)
        row["http_status"] = status
        row["content_type"] = content_type
        if not 200 <= status < 300:
            row.update(status="http_error", detail=f"HTTP {status} on {safe_host}")
        elif is_hls and b"#EXTM3U" not in data[:8192]:
            row.update(status="invalid_manifest", detail=f"HTTP {status}; HLS marker absent on {safe_host}")
        elif is_hls:
            row.update(status="http_ok_hls_manifest", detail=f"HTTP {status}; manifest marker present on {safe_host}")
        else:
            row.update(status="http_ok_unverified_media", detail=f"HTTP {status}; media/playback not decoded ({safe_host})")
    except urllib.error.HTTPError as e:
        row.update(status="http_error", http_status=e.code, detail=f"HTTP {e.code} on {safe_host}")
    except Exception as e:
        row.update(status="unreachable", detail=f"{type(e).__name__} on {safe_host}")
    return row

def main():
    os.makedirs(OUT, exist_ok=True)
    rows = parse_playlist(PLAYLIST)
    started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        checked = list(pool.map(check, rows))
    counts = Counter(r["status"] for r in checked)
    # Don't put raw URLs in reports; IPTV URLs can include access tokens.
    with open(os.path.join(OUT, "source-validation.csv"), "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["title", "category", "status", "http_status", "content_type", "detail"])
        writer.writeheader()
        for r in checked:
            writer.writerow({k: r.get(k, "") for k in writer.fieldnames})
    summary = {
        "entries_checked": len(checked), "elapsed_seconds": round(time.time() - started, 1),
        "status_counts": dict(counts),
        "important_limit": "HTTP reachability and an HLS marker do not prove playback, geo-availability, valid segments, codecs, or distribution rights."
    }
    with open(os.path.join(OUT, "source-validation-summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    print(json.dumps(summary, ensure_ascii=False))
    with open(os.environ.get("GITHUB_STEP_SUMMARY", "/dev/null"), "a", encoding="utf-8") as f:
        f.write("\n## IPTV source endpoint validation (QA)\n\n")
        f.write(f"- Endpoints checked: **{len(checked)}**\n")
        for status, count in sorted(counts.items()):
            f.write(f"- {status}: **{count}**\n")
        f.write("\nThis is an endpoint/manifest smoke test, not a guarantee of live playback.\n")
if __name__ == "__main__":
    main()
