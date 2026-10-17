#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <version> <flutter-linux-release-bundle> <output-directory>" >&2
  exit 2
fi

version="$1"
bundle="$(realpath "$2")"
output="$(realpath -m "$3")"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid package version: $version" >&2
  exit 2
}
[[ -x "$bundle/miltv_plus" ]] || {
  echo "Flutter Linux executable missing: $bundle/miltv_plus" >&2
  exit 1
}
[[ -d "$bundle/data" ]] || {
  echo "Flutter Linux data directory missing: $bundle/data" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
root="$work/root"
mkdir -p "$root/DEBIAN" "$root/opt/miltvplus" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/scalable/apps" "$output"
cp -a "$bundle/." "$root/opt/miltvplus/"

cat > "$root/DEBIAN/control" <<CONTROL
Package: miltvplus
Version: $version
Section: video
Priority: optional
Architecture: amd64
Maintainer: MILTVPLUS Project
Depends: libgtk-3-0 | libgtk-3-0t64, libblkid1, liblzma5, libsecret-1-0
Description: MILTVPLUS multimedia application
 Native Linux desktop application for the MILTVPLUS service.
CONTROL

cat > "$root/usr/bin/miltvplus" <<'LAUNCHER'
#!/bin/sh
exec /opt/miltvplus/miltv_plus "$@"
LAUNCHER
chmod 0755 "$root/usr/bin/miltvplus"

cat > "$root/usr/share/applications/miltvplus.desktop" <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=MILTVPLUS
Comment=MILTVPLUS multimedia application
Exec=miltvplus
Icon=miltvplus
Terminal=false
Categories=AudioVideo;Video;Player;
StartupNotify=true
DESKTOP

cat > "$root/usr/share/icons/hicolor/scalable/apps/miltvplus.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect x="4" y="4" width="120" height="120" rx="26" fill="#101820"/>
  <path d="M28 91V37h13l23 29 23-29h13v54H86V60L64 87 42 60v31z" fill="#22d3ee"/>
</svg>
SVG

dpkg-deb --build --root-owner-group "$root" "$output/MILTVPLUS-$version-Linux-amd64.deb"
