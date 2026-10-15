#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root_dir/android/app/src/main/AndroidManifest.xml"

if [[ ! -f "$manifest" ]]; then
  echo "Error: AndroidManifest.xml no existe. Ejecutá primero tool/bootstrap_android.sh." >&2
  exit 1
fi

python3 - "$manifest" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
permissions = [
    '    <uses-permission android:name="android.permission.INTERNET" />',
    '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />',
]
for permission in permissions:
    name = permission.split('"')[1]
    if name not in text:
        marker = '<application'
        if marker not in text:
            raise SystemExit("No se encontró <application en AndroidManifest.xml; no se modificó el archivo.")
        text = text.replace(marker, permission + "\n\n    " + marker, 1)

path.write_text(text, encoding="utf-8")
print("Permisos OTA verificados: INTERNET y REQUEST_INSTALL_PACKAGES.")
PY
