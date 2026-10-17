#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/qa_supabase_guard.sh"

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

qa_ref="$(qa_project_ref_from_url 'https://abcdefghijklmnopqrst.supabase.co')" || fail 'valid QA URL rejected'
[[ "$qa_ref" == 'abcdefghijklmnopqrst' ]] || fail 'valid QA ref parsed incorrectly'
pass 'valid 20-character QA project URL'

if qa_project_ref_from_url 'https://abcdefghijklmnopqrs.supabase.co' >/dev/null; then
  fail '19-character project ref accepted'
fi
pass 'reject 19-character project ref'

if qa_project_ref_from_url 'https://abcdefghijklmnopqrst.supabase.co/rest/v1' >/dev/null; then
  fail 'QA URL with path accepted'
fi
pass 'reject QA URL containing a path'

if qa_url_points_to_production 'https://abcdefghijklmnopqrst.supabase.co' 'https://abcdefghijklmnopqrst.supabase.co'; then
  pass 'detect identical QA and production project'
else
  fail 'identical QA/production project not detected'
fi

if qa_url_points_to_production 'https://abcdefghijklmnopqrst.supabase.co' ' https://abcdefghijklmnopqrst.supabase.co/ '; then
  pass 'detect production URL with surrounding whitespace and trailing slash'
else
  fail 'production URL normalization bypassed isolation check'
fi

if qa_url_points_to_production 'https://abcdefghijklmnopqrst.supabase.co' 'https://abcdefghijklmnopqrst.supabase.co/rest/v1?select=*'; then
  pass 'detect production URL with path and query'
else
  fail 'production path/query bypassed isolation check'
fi

if qa_url_points_to_production 'https://abcdefghijklmnopqrst.supabase.co' 'https://zyxwvutsrqponmlkjihg.supabase.co/'; then
  fail 'different QA and production refs treated as identical'
fi
pass 'allow distinct QA and production projects'

if qa_url_points_to_production 'https://abcdefghijklmnopqrst.supabase.co' 'https://abcdefghijklmnopqrst.supabase.co.evil.example'; then
  fail 'deceptive production hostname accepted'
fi
pass 'reject deceptive production hostname'

printf 'All QA Supabase guard tests passed.\n'
