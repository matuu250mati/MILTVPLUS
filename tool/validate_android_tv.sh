#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root_dir/android/app/src/main/AndroidManifest.xml"
banner="$root_dir/android/app/src/main/res/drawable-nodpi/tv_banner.png"
adaptive_icon="$root_dir/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
icon_foreground="$root_dir/android/app/src/main/res/drawable/miltvplus_ic_platform_robot.xml"

if [[ ! -f "$manifest" ]]; then
  echo "::error::AndroidManifest.xml no existe después de preparar Android."
  exit 1
fi
if [[ ! -f "$banner" ]]; then
  echo "::error::Falta el recurso android:banner para Android TV."
  exit 1
fi
if [[ ! -f "$adaptive_icon" || ! -f "$icon_foreground" ]]; then
  echo "::error::Falta el icono adaptativo personalizado de MILTVPLUS."
  exit 1
fi

python3 - "$manifest" "$banner" <<'PY'
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

path = sys.argv[1]
banner_path = sys.argv[2]
android = "{http://schemas.android.com/apk/res/android}"
tree = ET.parse(path)
root = tree.getroot()

features = {
    item.get(android + "name"): item
    for item in root.findall("uses-feature")
}
for name in ("android.hardware.touchscreen", "android.software.leanback"):
    feature = features.get(name)
    if feature is None or feature.get(android + "required") != "false":
        raise SystemExit(f"Android TV validation failed: {name} must be declared required=false")

application = root.find("application")
if application is None:
    raise SystemExit("Android TV validation failed: application element is missing")
if application.get(android + "banner") != "@drawable/tv_banner":
    raise SystemExit("Android TV validation failed: application banner is missing or incorrect")
if application.get(android + "usesCleartextTraffic") != "false":
    raise SystemExit("Android security validation failed: cleartext traffic must be disabled")

activity = application.find("activity")
if activity is None:
    raise SystemExit("Android TV validation failed: launcher activity is missing")
categories = {
    category.get(android + "name")
    for intent_filter in activity.findall("intent-filter")
    for category in intent_filter.findall("category")
}
for category in ("android.intent.category.LAUNCHER", "android.intent.category.LEANBACK_LAUNCHER"):
    if category not in categories:
        raise SystemExit(f"Android TV validation failed: missing {category}")

permissions = {item.get(android + "name") for item in root.findall("uses-permission")}
if "android.permission.INTERNET" not in permissions:
    raise SystemExit("Android validation failed: INTERNET permission is missing")

metadata = {item.get(android + "name"): item.get(android + "value") for item in application.findall("meta-data")}
if metadata.get("flutterEmbedding") != "2":
    raise SystemExit("Android validation failed: Flutter embedding v2 is required")

icon_path = path.rsplit("AndroidManifest.xml", 1)[0] + "res/mipmap-anydpi-v26/ic_launcher.xml"
icon_root = ET.parse(icon_path).getroot()
if icon_root.tag != "adaptive-icon":
    raise SystemExit("Icon validation failed: ic_launcher must be an adaptive-icon")
foreground = icon_root.find("foreground")
background = icon_root.find("background")
if foreground is None or foreground.get(android + "drawable") != "@drawable/miltvplus_ic_platform_robot":
    raise SystemExit("Icon validation failed: custom MILTVPLUS foreground is missing")
if background is None or background.get(android + "drawable") != "@drawable/miltvplus_icon_background":
    raise SystemExit("Icon validation failed: MILTVPLUS background is missing")

# Android TV requiere un banner opaco 320x180 con marca visible.
with open(banner_path, "rb") as banner_file:
    png = banner_file.read()
if not png.startswith(b"\x89PNG\r\n\x1a\n") or len(png) < 33:
    raise SystemExit("Android TV validation failed: banner is not a valid PNG")
width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", png[16:29])
if (width, height) != (320, 180) or bit_depth != 8 or color_type != 6:
    raise SystemExit("Android TV validation failed: banner must be a 320x180 RGBA PNG")
offset = 8
compressed = bytearray()
while offset + 12 <= len(png):
    length = struct.unpack(">I", png[offset:offset + 4])[0]
    kind = png[offset + 4:offset + 8]
    data = png[offset + 8:offset + 8 + length]
    if kind == b"IDAT":
        compressed.extend(data)
    offset += length + 12
    if kind == b"IEND":
        break
raw = zlib.decompress(bytes(compressed))
row_bytes = 1 + width * 4
if len(raw) != row_bytes * height:
    raise SystemExit("Android TV validation failed: banner PNG pixel data is incomplete")
for row in range(height):
    row_start = row * row_bytes
    for pixel in range(width):
        if raw[row_start + 1 + pixel * 4 + 3] != 255:
            raise SystemExit("Android TV validation failed: banner background must be fully opaque")

print("Android manifest validated: mobile + Android TV launcher, adaptive MILTVPLUS icon, banner, internet, cleartext disabled, Flutter embedding v2.")
PY
