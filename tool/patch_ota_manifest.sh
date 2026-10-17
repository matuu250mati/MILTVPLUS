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
    '    <uses-permission android:name="android.permission.RECORD_AUDIO" />',
]
for permission in permissions:
    name = permission.split('"')[1]
    if name not in text:
        marker = '<application'
        if marker not in text:
            raise SystemExit("No se encontró <application en AndroidManifest.xml; no se modificó el archivo.")
        text = text.replace(marker, permission + "\n\n    " + marker, 1)

# Speech recognition queries are required by Android 11+ package visibility.
queries = '''    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>'''
if 'android.speech.RecognitionService' not in text:
    marker = '<application'
    if marker not in text:
        raise SystemExit("No se encontró <application para agregar la consulta de reconocimiento de voz.")
    text = text.replace(marker, queries + "\\n\\n    " + marker, 1)

path.write_text(text, encoding="utf-8")
print("Permisos verificados: INTERNET, REQUEST_INSTALL_PACKAGES y RECORD_AUDIO; consulta de reconocimiento de voz verificada.")
PY
