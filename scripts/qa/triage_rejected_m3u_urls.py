#!/usr/bin/env python3
"""Read-only triage of M3U entries rejected by the QA sync's strict HTTPS-HLS rule.

Never writes to Supabase. Never stores or prints full stream URLs, query values,
credentials, or token-bearing paths. Network probes read at most 4096 bytes.
"""
from __future__ import annotations

import concurrent.futures
import hashlib
import json
import re
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

FUNCTION = Path("supabase/functions/sync-m3u-catalog/index.ts")
OUT = Path("m3u-rejected-url-triage.json")
TIMEOUT = 6
MAX_WORKERS = 12
MAX_READ = 4096
UA = "MILTVPLUS-QA-read-only-url-triage/1.0"


def source_definitions(text: str):
    start = text.index("const SOURCES: Source[] = [")
    end = text.index("\n];", start)
    block = text[start:end]
    pattern = re.compile(r'\{\s*name:\s*"([^"]+)"\s*,\s*url:\s*"([^"]+)"\s*,\s*category:')
    return [(m.group(1), m.group(2)) for m in pattern.finditer(block)]


def entry_reason(raw_url: str, title: str):
    if not title:
        return "missing_title"
    try:
        u = urllib.parse.urlsplit(raw_url.strip())
        if u.scheme.lower() != "https":
            return "non_https"
        path = urllib.parse.unquote(u.path).lower()
        if re.search(r"\.mpd(?:;[^/]*)?$", path):
            return "dash_requires_player_compatibility_check"
        if not re.search(r"\.m3u8(?:;[^/]*)?$", path):
            return "non_m3u8_https"
        if u.username or u.password or not u.hostname:
            return "unsafe_or_invalid_url"
        return None
    except Exception:
        return "invalid_url"


def safe_host(raw_url: str):
    try:
        return urllib.parse.urlsplit(raw_url).hostname or "(invalid)"
    except Exception:
        return "(invalid)"


def probe(candidate_url: str, probe_kind: str):
    result = {
        "probe_kind": probe_kind,
        "status": "network_error",
        "http_status": None,
        "content_type": "",
        "looks_like_hls": False,
        "looks_like_dash": False,
        "looks_like_media": False,
        "redirect_host": "",
    }
    try:
        req = urllib.request.Request(
            candidate_url,
            headers={
                "User-Agent": UA,
                "Accept": "application/vnd.apple.mpegurl, application/x-mpegURL, application/dash+xml, video/*, */*",
                "Range": f"bytes=0-{MAX_READ - 1}",
                "Connection": "close",
            },
            method="GET",
        )
        context = ssl.create_default_context()
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=context) as response:
            result["http_status"] = int(response.status)
            result["status"] = "http_success" if 200 <= response.status < 300 else "http_non_success"
            result["content_type"] = (response.headers.get("Content-Type", "").split(";")[0])[:100]
            try:
                result["redirect_host"] = urllib.parse.urlsplit(response.geturl()).hostname or ""
            except Exception:
                pass
            body = response.read(MAX_READ)
            head = body.lstrip()[:512].lower()
            result["looks_like_hls"] = head.startswith(b"#extm3u")
            result["looks_like_dash"] = b"<mpd" in head[:256] or b":mpd" in head[:256]
            ctype = result["content_type"].lower()
            result["looks_like_media"] = ctype.startswith(("video/", "audio/")) or body[:1] == b"\x47"
            if result["looks_like_hls"]:
                result["status"] = "valid_hls_manifest"
            elif result["looks_like_dash"]:
                result["status"] = "valid_dash_manifest"
            elif result["http_status"] in (200, 206) and result["looks_like_media"]:
                result["status"] = "media_response_not_manifest"
            elif result["http_status"] in (200, 206):
                result["status"] = "http_ok_unconfirmed_format"
    except urllib.error.HTTPError as e:
        result["http_status"] = int(e.code)
        result["status"] = "http_error"
        try:
            result["content_type"] = (e.headers.get("Content-Type", "").split(";")[0])[:100]
        except Exception:
            pass
        try:
            e.close()
        except Exception:
            pass
    except Exception as e:
        # Keep exception messages out of artifacts because they can contain the URL.
        result["status"] = "timeout_or_tls_error" if isinstance(e, (TimeoutError, ssl.SSLError)) else type(e).__name__
    return result


def main():
    text = FUNCTION.read_text(encoding="utf-8")
    sources = source_definitions(text)
    if not sources:
        raise SystemExit("Could not read configured M3U sources from the sync function.")

    entries = []
    source_errors = []
    for source_name, source_url in sources:
        try:
            req = urllib.request.Request(source_url, headers={"User-Agent": UA, "Accept": "application/x-mpegURL, text/plain, */*"})
            with urllib.request.urlopen(req, timeout=TIMEOUT, context=ssl.create_default_context()) as response:
                body = response.read()
            decoded = body.decode("utf-8-sig", errors="replace")
            if not decoded.lstrip().startswith("#EXTM3U"):
                source_errors.append({"source": source_name, "status": "not_m3u_playlist"})
                continue
            current_title = ""
            for line in decoded.splitlines():
                line = line.strip()
                if line.startswith("#EXTINF:"):
                    current_title = line.split(",", 1)[1].strip() if "," in line else ""
                elif line and not line.startswith("#") and current_title:
                    reason = entry_reason(line, current_title)
                    if reason:
                        try:
                            parts = urllib.parse.urlsplit(line)
                            is_http = parts.scheme.lower() == "http"
                            candidate = urllib.parse.urlunsplit(("https", parts.netloc, parts.path, parts.query, parts.fragment)) if is_http else line
                            probe_kind = "try_https_upgrade" if is_http else "inspect_https_endpoint"
                            host = parts.hostname or "(invalid)"
                        except Exception:
                            candidate, probe_kind, host = "", "invalid_url", "(invalid)"
                        entries.append({
                            "source": source_name,
                            "title": current_title[:160],
                            "reason": reason,
                            "host": host,
                            "url_sha256": hashlib.sha256(line.encode("utf-8", errors="replace")).hexdigest(),
                            "candidate": candidate,
                            "probe_kind": probe_kind,
                        })
                    current_title = ""
        except urllib.error.HTTPError as e:
            source_errors.append({"source": source_name, "status": f"HTTP_{e.code}"})
        except Exception as e:
            source_errors.append({"source": source_name, "status": type(e).__name__})

    # One probe per unique candidate URL; duplicate rows reuse the result.
    unique = {}
    for entry in entries:
        if entry["candidate"]:
            unique.setdefault(entry["candidate"], entry["probe_kind"])
    results = {}
    started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(probe, url, kind): url for url, kind in unique.items()}
        for future in concurrent.futures.as_completed(futures):
            url = futures[future]
            try:
                results[url] = future.result()
            except Exception:
                results[url] = {"probe_kind": unique[url], "status": "probe_failed", "http_status": None, "content_type": "", "looks_like_hls": False, "looks_like_dash": False, "looks_like_media": False, "redirect_host": ""}

    for entry in entries:
        result = results.get(entry.pop("candidate"), {
            "probe_kind": entry.pop("probe_kind", "invalid_url"),
            "status": "not_probed",
            "http_status": None,
            "content_type": "",
            "looks_like_hls": False,
            "looks_like_dash": False,
            "looks_like_media": False,
            "redirect_host": "",
        })
        entry.update(result)

    reason_counts = Counter(e["reason"] for e in entries)
    status_counts = Counter(e["status"] for e in entries)
    source_reason_counts = {}
    for entry in entries:
        key = entry["source"]
        source_reason_counts.setdefault(key, Counter())[entry["reason"]] += 1

    report = {
        "mode": "read_only_no_database_writes",
        "configured_sources": len(sources),
        "source_fetch_errors": source_errors,
        "rejected_entries_seen": len(entries),
        "unique_candidate_urls_probed": len(unique),
        "elapsed_seconds": round(time.time() - started, 1),
        "reason_counts": dict(sorted(reason_counts.items())),
        "probe_status_counts": dict(sorted(status_counts.items())),
        "per_source_reason_counts": {k: dict(v) for k, v in sorted(source_reason_counts.items())},
        "entries": entries,
        "security_note": "Full URLs, query values, credentials and token-bearing paths are intentionally omitted. url_sha256 can identify a URL across reports but cannot recover it.",
        "limitations": "A successful manifest/HTTP response is a point-in-time technical signal, not a guarantee of sustained playback, authorization, or redistribution rights. HTTP-to-HTTPS candidates are only probed via HTTPS; the HTTP URL itself is not contacted.",
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Read-only triage complete. Database writes: 0.")
    print(f"Sources: {len(sources)}; rejected entries examined: {len(entries)}; unique candidate URLs probed: {len(unique)}.")
    print(f"Source fetch errors: {len(source_errors)}; rejection reasons: {json.dumps(dict(reason_counts), sort_keys=True)}")
    print(f"Probe outcomes: {json.dumps(dict(status_counts), sort_keys=True)}")
    print(f"Report: {OUT}; full URLs and secrets omitted.")


if __name__ == "__main__":
    main()
