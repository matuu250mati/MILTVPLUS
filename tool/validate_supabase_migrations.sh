#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

migration_paths = sorted(Path("supabase/migrations").glob("*.sql"))
files = [Path("supabase/schema.sql"), *migration_paths]
if not migration_paths:
    print("No Supabase migrations found.", file=sys.stderr)
    sys.exit(1)

required_columns = {
    "id", "title", "description", "stream_url", "poster_url",
    "duration_seconds", "series_title", "season_number",
    "episode_number", "media_type", "moderation_status", "created_at",
}
errors = []
for path in files:
    sql = path.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*do\s+\$(?:\s|$)", sql):
        errors.append(f"{path}: invalid single-dollar DO block delimiter")
    # A table-wide SELECT grant would expose columns such as user_id and
    # rights_confirmed to anon/authenticated when an approved row is visible.
    for grant in re.finditer(
        r"grant\s+((?:select|insert|update|delete|truncate|references|trigger)"
        r"(?:\s*,\s*(?:select|insert|update|delete|truncate|references|trigger))*)"
        r"\s+on\s+([^;]*);",
        sql,
        re.IGNORECASE | re.DOTALL,
    ):
        privileges = {item.strip().lower() for item in grant.group(1).split(",")}
        target = grant.group(2).lower()
        if "select" in privileges and "public.content_submissions" in target:
            errors.append(f"{path}: broad SELECT grant on content_submissions")
    if path.name in {
        "schema.sql",
        "20261021200000_catalog_metadata_and_submissions.sql",
        "20261021210000_catalog_rls_hardening.sql",
        "20261022090000_content_submissions_column_privileges.sql",
    }:
        if not re.search(
            r"revoke\s+select\s+on\s+(?:table\s+)?public\.content_submissions\s+from\s+anon\s*,\s*authenticated",
            sql,
            re.IGNORECASE,
        ):
            errors.append(f"{path}: missing table-level SELECT revocation")
        # Fresh schema must not grant anonymous reads; historical migrations
        # are checked for their explicit column allowlist and corrected by the
        # final authenticated-only migration.
        target_roles = (
            r"authenticated"
            if path.name == "schema.sql"
            else r"anon\\s*,\\s*authenticated"
        )
        match = re.search(
            r"grant\\s+select\\s*\\((.*?)\\)\\s*on\\s+public\\.content_submissions\\s+to\\s+" + target_roles,
            sql,
            re.IGNORECASE | re.DOTALL,
        )
        if not match:
            errors.append(f"{path}: missing explicit public column allowlist")
        else:
            granted = {name.strip().lower() for name in match.group(1).split(",")}
            missing = sorted(required_columns - granted)
            forbidden = sorted({"user_id", "rights_confirmed"} & granted)
            if missing:
                errors.append(f"{path}: missing required catalog columns: {', '.join(missing)}")
            if forbidden:
                errors.append(f"{path}: private columns must not be granted: {', '.join(forbidden)}")

# Enforce authenticated-only catalog access in the corrective migration.
access_migration = Path("supabase/migrations/20261022100000_enforce_authenticated_catalog_access.sql")
if not access_migration.exists():
    errors.append(f"{access_migration}: missing authenticated-only access migration")
else:
    access_sql = access_migration.read_text(encoding="utf-8")
    for table in ("channels", "movies", "series", "episodes", "content_submissions"):
        if not re.search(
            rf"create\s+policy\s+[^;]+on\s+public\.{table}\s+for\s+select\s+to\s+authenticated",
            access_sql,
            re.IGNORECASE | re.DOTALL,
        ):
            errors.append(f"{access_migration}: {table} SELECT policy must target authenticated only")
        if re.search(
            rf"create\s+policy\s+[^;]+on\s+public\.{table}\s+for\s+select\s+to\s+anon\b",
            access_sql,
            re.IGNORECASE | re.DOTALL,
        ):
            errors.append(f"{access_migration}: anonymous SELECT policy is forbidden for {table}")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

print(f"Supabase submission-column security checks passed across {len(files)} SQL files.")
PY
