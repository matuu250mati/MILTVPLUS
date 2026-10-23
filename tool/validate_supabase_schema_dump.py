#!/usr/bin/env python3
"""Validate the minimum production catalog schema from a Supabase pg_dump file."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    print("Usage: validate_supabase_schema_dump.py PATH_TO_SCHEMA_DUMP", file=sys.stderr)
    sys.exit(2)

path = Path(sys.argv[1])
if not path.is_file() or path.stat().st_size == 0:
    print(f"ERROR: schema dump is missing or empty: {path}", file=sys.stderr)
    sys.exit(1)

sql = path.read_text(encoding="utf-8")
required = {
    "channels": {"id", "title", "url_stream", "stream_urls", "category", "country_code", "is_published", "sort_order", "logo"},
    "movies": {"id", "tmdb_id", "title", "synopsis", "category", "genres", "logo", "backdrop_url", "url_stream", "stream_urls", "release_year", "duration_seconds", "country_code", "is_published", "created_at", "updated_at"},
    "series": {"id", "tmdb_id", "title", "synopsis", "category", "genres", "logo", "backdrop_url", "release_year", "country_code", "is_published", "created_at", "updated_at"},
    "episodes": {"id", "series_id", "title", "synopsis", "logo", "url_stream", "duration_seconds", "is_published", "season_number", "episode_number", "created_at"},
    "content_submissions": {"id", "title", "description", "stream_url", "poster_url", "duration_seconds", "series_title", "season_number", "episode_number", "media_type", "moderation_status", "rights_confirmed", "created_at"},
}
errors = []
for table, columns in required.items():
    match = re.search(
        rf"CREATE TABLE\s+(?:public\.)?{re.escape(table)}\s*\((.*?)\n\);",
        sql, re.IGNORECASE | re.DOTALL,
    )
    if not match:
        errors.append(f"{table}: table definition not found in remote schema dump")
        continue
    present = {name.lower() for name in re.findall(
        r"^\s*([a-z_][a-z0-9_]*)\s+", match.group(1), re.IGNORECASE | re.MULTILINE
    )}
    missing = sorted(columns - present)
    if missing:
        errors.append(f"{table}: missing required columns: {', '.join(missing)}")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

print(f"Production schema verified: all required columns exist in {len(required)} catalog tables.")
