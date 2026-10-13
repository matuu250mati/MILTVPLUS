#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root_dir/android/app/src/main/AndroidManifest.xml"
banner="$root_dir/android/app/src/main/res/drawable/tv_banner.xml"

if [[ ! -f "$manifest" ]]; then
  echo "::error::AndroidManifest.xml no existe después de preparar Android."
  exit 1
fi
if [[ ! -f "$banner" ]]; then
  echo "::error::Falta el recurso android:banner para Android TV."
  exit 1
fi

python3 - "$manifest" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
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

print("Android manifest validated: mobile + Android TV launcher, non-touch TV support, banner, internet, cleartext disabled, Flutter embedding v2.")
PY
