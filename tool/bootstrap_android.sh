#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: Flutter no está instalado o no está en PATH." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create --platforms=android --project-name miltv_plus --org com.miltvplus "$tmp_dir/miltv-scaffold"
rm -rf "$root_dir/android"
cp -R "$tmp_dir/miltv-scaffold/android" "$root_dir/android"

echo "Estructura Android generada con la versión de Flutter instalada."
echo "Siguiente paso: cd al proyecto y ejecutar flutter pub get."
