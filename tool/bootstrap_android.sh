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

# Android TV / TV Box y móviles: reemplaza el manifiesto generado por Flutter
# por uno mínimo y mantenible para MIL TV Plus.
cat > "$root_dir/android/app/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:name="${applicationName}"
        android:label="MIL TV Plus"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false"
        android:hardwareAccelerated="true"
        android:allowBackup="false"
        android:supportsRtl="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
MANIFEST

echo "Estructura Android generada y manifiesto MIL TV Plus configurado para móviles, Android TV y TV Box."
echo "Siguiente paso: cd al proyecto y ejecutar flutter pub get."
