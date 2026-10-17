#!/usr/bin/env bash
# Shared QA/production Supabase URL validation. Safe to source from CI and tests.

qa_project_ref_from_url() {
  local url="${1:-}"
  [[ "$url" =~ ^https://([a-z0-9]{19,20})[.]supabase[.]co$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

production_project_ref_from_url() {
  local url="${1:-}"
  url="$(printf '%s' "$url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  # Production may include a trailing slash, path, query or fragment; identity is its exact host ref.
  [[ "$url" =~ ^https?://([a-z0-9]{19,20})[.]supabase[.]co([/:?#].*)?$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

qa_url_points_to_production() {
  local qa_ref production_ref
  qa_ref="$(qa_project_ref_from_url "${1:-}")" || return 2
  production_ref="$(production_project_ref_from_url "${2:-}")" || return 1
  [[ -n "$production_ref" && "$qa_ref" == "$production_ref" ]]
}
