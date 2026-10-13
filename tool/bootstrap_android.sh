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

# Recursos visuales propios de MILTV PLUS.
mkdir -p "$root_dir/android/app/src/main/res/drawable"
mkdir -p "$root_dir/android/app/src/main/res/color"
mkdir -p "$root_dir/android/app/src/main/res/values"

cat > "$root_dir/android/app/src/main/res/drawable/tv_banner.xml" <<'BANNER'
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#071426" />
        </shape>
    </item>
    <item
        android:drawable="@mipmap/ic_launcher"
        android:width="104dp"
        android:height="104dp"
        android:gravity="center" />
</layer-list>
BANNER

cat > "$root_dir/android/app/src/main/res/values/colors.xml" <<'COLORS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="miltvplus_surface">#121212</color>
    <color name="miltvplus_accent">#E50914</color>
</resources>
COLORS

cat > "$root_dir/android/app/src/main/res/color/miltvplus_accelerated_selector.xml" <<'SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:color="@color/miltvplus_surface"
        android:state_accelerated="false" />
    <item android:color="@color/miltvplus_accent" />
</selector>
SELECTOR

# Variante del segundo selector recibido; mantiene los colores de marca.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_accelerated_selector_secondary.xml" <<'SELECTOR_SECONDARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:color="@color/miltvplus_surface"
        android:state_accelerated="false" />
    <item android:color="@color/miltvplus_accent" />
</selector>
SELECTOR_SECONDARY

# Selector para controles habilitados/deshabilitados.
# Se reemplazan los IDs numéricos decompilados por atributos Android con nombre.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_enabled_selector.xml" <<'ENABLED_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item android:color="?android:attr/colorControlNormal" />
</selector>
ENABLED_SELECTOR

# Selector de texto alternativo: deshabilitado usa color secundario; habilitado, color primario.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_text_enabled_selector.xml" <<'TEXT_ENABLED_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
TEXT_ENABLED_SELECTOR

# Selector para estado presionado: usa el acento de MILTV PLUS con distinta opacidad.
# Los IDs numéricos del XML decompilado no son portables entre aplicaciones.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_pressed_alpha_selector.xml" <<'PRESSED_ALPHA_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_pressed="true"
        android:color="@color/miltvplus_accent"
        android:alpha="0.65" />
    <item
        android:color="@color/miltvplus_accent"
        android:alpha="1.0" />
</selector>
PRESSED_ALPHA_SELECTOR

# Variante del selector presionado con una opacidad más suave para otros controles.
# Los recursos numéricos originales no se pueden traducir sin el APK/tabla de recursos de origen.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_pressed_alpha_selector_secondary.xml" <<'PRESSED_ALPHA_SELECTOR_SECONDARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="true"
        android:state_pressed="true"
        android:color="@color/miltvplus_accent"
        android:alpha="0.55" />
    <item
        android:color="@color/miltvplus_accent"
        android:alpha="0.85" />
</selector>
PRESSED_ALPHA_SELECTOR_SECONDARY

# Selector de color para controles habilitados/deshabilitados, variante de contraste.
# Los IDs del APK de origen se sustituyen por colores semánticos de MILTV PLUS.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_control_state_selector.xml" <<'CONTROL_STATE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="@color/miltvplus_accent" />
</selector>
CONTROL_STATE_SELECTOR

# Segundo selector de estado para texto/íconos secundarios.
# Usa nombres semánticos en lugar de IDs numéricos del APK de origen.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_control_state_selector_secondary.xml" <<'CONTROL_STATE_SELECTOR_SECONDARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
CONTROL_STATE_SELECTOR_SECONDARY

# Selector de estado adicional para controles con énfasis de marca.
# Los IDs numéricos del XML decompilado no permiten conocer los colores originales.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_brand_state_selector.xml" <<'BRAND_STATE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="@color/miltvplus_accent" />
</selector>
BRAND_STATE_SELECTOR

# Variante secundaria del selector de estado de marca para texto/íconos.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_brand_state_selector_secondary.xml" <<'BRAND_STATE_SELECTOR_SECONDARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
BRAND_STATE_SELECTOR_SECONDARY

# Selector de tres estados para botones/elementos seleccionables.
# Los IDs numéricos del APK original se sustituyen por colores semánticos de MILTV PLUS.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_interaction_state_selector.xml" <<'INTERACTION_STATE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_pressed="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_selected="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="@color/miltvplus_surface" />
</selector>
INTERACTION_STATE_SELECTOR

# Selectores de estado adicionales adaptados a la paleta y al tema de MILTV PLUS.
# Los IDs numéricos del APK de origen no se pueden resolver sin su tabla de recursos.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_enabled_state_selector_tertiary.xml" <<'ENABLED_STATE_TERTIARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="@color/miltvplus_accent" />
</selector>
ENABLED_STATE_TERTIARY

cat > "$root_dir/android/app/src/main/res/color/miltvplus_enabled_state_selector_quaternary.xml" <<'ENABLED_STATE_QUATERNARY'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
ENABLED_STATE_QUATERNARY

# Selector de control marcado: atenuado cuando está deshabilitado, acento al marcarse.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_checked_state_selector.xml" <<'CHECKED_STATE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item
        android:state_checked="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/colorControlNormal" />
</selector>
CHECKED_STATE_SELECTOR

# Selectores compuestos para foco, pulsación, selección y activación.
# Los atributos ?7F0400B7/?7F0400B9 se sustituyen por colores semánticos del tema MILTV PLUS.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_interactive_control_selector.xml" <<'INTERACTIVE_CONTROL_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_pressed="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_activated="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_selected="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_checked="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/colorControlNormal" />
</selector>
INTERACTIVE_CONTROL_SELECTOR

# Variante atenuada cuando está deshabilitada; acento en estado normal.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_interactive_disabled_accent_selector.xml" <<'INTERACTIVE_DISABLED_ACCENT_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="@color/miltvplus_accent"
        android:alpha="?android:attr/disabledAlpha" />
    <item android:color="@color/miltvplus_accent" />
</selector>
INTERACTIVE_DISABLED_ACCENT_SELECTOR

# Selector para elementos sin foco ni pulsación: color secundario; interacción: acento.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_pressed_selector.xml" <<'FOCUS_PRESSED_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item
        android:state_focused="false"
        android:state_pressed="false"
        android:color="?android:attr/textColorSecondary" />
    <item android:color="@color/miltvplus_accent" />
</selector>
FOCUS_PRESSED_SELECTOR

# Selectores de opacidad, estado marcado y foco para la interfaz MILTV PLUS.
# Los IDs del APK original se sustituyen por colores semánticos de la marca y del tema.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_checked_overlay_selector.xml" <<'CHECKED_OVERLAY_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/colorForeground"
        android:alpha="0.1" />
    <item
        android:state_checked="true"
        android:color="@color/miltvplus_accent"
        android:alpha="0.3" />
    <item
        android:color="?android:attr/colorForeground"
        android:alpha="0.3" />
</selector>
CHECKED_OVERLAY_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_checked_text_selector.xml" <<'CHECKED_TEXT_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_checked="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
CHECKED_TEXT_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_indicator_selector.xml" <<'FOCUS_INDICATOR_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="@color/miltvplus_accent" />
</selector>
FOCUS_INDICATOR_SELECTOR


# Selectores para foco y selección, adaptados semánticamente a la paleta MILTV PLUS.
# Los IDs @7F060xxx son propios del APK de origen y no revelan sus valores reales.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_selected_selector.xml" <<'FOCUS_SELECTED_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_selected="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
FOCUS_SELECTED_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_selected_secondary_selector.xml" <<'FOCUS_SELECTED_SECONDARY_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_selected="true"
        android:color="?android:attr/textColorPrimary" />
    <item android:color="?android:attr/textColorSecondary" />
</selector>
FOCUS_SELECTED_SECONDARY_SELECTOR

# El tercer XML recibido usa el mismo color en los tres estados; equivale al
# miltvplus_focus_indicator_selector.xml definido arriba y no necesita duplicarse.


# Selectores adicionales de foco/selección adaptados a los colores semánticos de MILTV PLUS.
# Los IDs @7F060xxx son locales al APK de origen y no se pueden resolver de forma fiable aquí.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_selected_accent_selector.xml" <<'FOCUS_SELECTED_ACCENT_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_selected="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/textColorPrimary" />
</selector>
FOCUS_SELECTED_ACCENT_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_surface_selector.xml" <<'FOCUS_SURFACE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="@color/miltvplus_surface" />
</selector>
FOCUS_SURFACE_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_selected_contrast_selector.xml" <<'FOCUS_SELECTED_CONTRAST_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:color="?android:attr/textColorPrimary" />
</selector>
FOCUS_SELECTED_CONTRAST_SELECTOR

# Android TV / TV Box y móviles: manifiesto para MILTV PLUS.
cat > "$root_dir/android/app/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
    <uses-feature
        android:name="android.software.leanback"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.gamepad"
        android:required="false" />

    <supports-screens
        android:smallScreens="true"
        android:normalScreens="true"
        android:largeScreens="true"
        android:xlargeScreens="true"
        android:anyDensity="true" />

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:name="${applicationName}"
        android:label="MILTV PLUS"
        android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/tv_banner"
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

echo "Estructura Android generada con selectores de color MILTV PLUS y manifiesto para móviles, Android TV y TV Box."
echo "Siguiente paso: ejecutar flutter pub get, flutter analyze y las pruebas del proyecto."
