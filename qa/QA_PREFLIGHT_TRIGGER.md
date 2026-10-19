# MILTVPLUS-QA read-only M3U preflight trigger

This file exists only to trigger the guarded workflow on `qa/deploy-m3u-sync-isolated-2026-10-18` using the `[run-qa-preflight]` commit-message gate. The workflow is expected to deploy only to its hardcoded QA project reference and run `dry_run: true`; no live catalog sync is authorized by this file.
