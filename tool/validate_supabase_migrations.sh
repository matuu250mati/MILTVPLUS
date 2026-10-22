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
        # Match the complete column-grant statement and inspect its role list.
        grants = list(re.finditer(
            r"grant\s+select\s*\((.*?)\)\s*on\s+public\.content_submissions\s+to\s+([^;]+);",
            sql,
            re.IGNORECASE | re.DOTALL,
        ))
        match = next(
            (
                grant for grant in grants
                if (
                    (path.name == "schema.sql" and grant.group(2).strip().lower() == "authenticated")
                    or (path.name != "schema.sql" and re.fullmatch(r"anon\s*,\s*authenticated", grant.group(2).strip(), re.IGNORECASE))
                )
            ),
            None,
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

# Fresh installs must define the rights column before the RLS insert policy uses it.
schema_sql = Path("supabase/schema.sql").read_text(encoding="utf-8")
if not re.search(r"rights_confirmed\s+boolean\s+not\s+null\s+default\s+false", schema_sql, re.IGNORECASE):
    errors.append("supabase/schema.sql: missing rights_confirmed column")
if not re.search(r"constraint\s+content_submission_rights\s+check\s*\(\s*rights_confirmed\s*\)", schema_sql, re.IGNORECASE):
    errors.append("supabase/schema.sql: missing rights-confirmation constraint")

# Enforce authenticated-only catalog access in the corrective migration.
access_migration = Path("supabase/migrations/20261022100000_enforce_authenticated_catalog_access.sql")
if not access_migration.exists():
    errors.append(f"{access_migration}: missing authenticated-only access migration")
else:
    access_sql = access_migration.read_text(encoding="utf-8")
    rights_add = re.search(r"alter\s+table\s+public\.content_submissions\s+add\s+column\s+if\s+not\s+exists\s+rights_confirmed\s+boolean\s+not\s+null\s+default\s+false", access_sql, re.IGNORECASE)
    submit_policy = re.search(r"""create\s+policy\s+['"]Users submit pending content['"].*?with\s+check\s*\((.*?)\);""", access_sql, re.IGNORECASE | re.DOTALL)
    if not rights_add:
        errors.append(f"{access_migration}: must add rights_confirmed before using it in RLS")
    elif submit_policy and not re.search(r"\brights_confirmed\b", submit_policy.group(1), re.IGNORECASE):
        errors.append(f"{access_migration}: submission policy must require rights_confirmed")
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
