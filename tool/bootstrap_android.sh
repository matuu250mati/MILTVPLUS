#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: Flutter no está instalado o no está en PATH." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Keep Android 5.0 (API 21) as the declared minimum in generated Android projects.
# Apply this on both fresh scaffolds and already-complete Android directories.
ensure_min_android_sdk() {
  local gradle_file="$root_dir/android/app/build.gradle.kts"
  if [[ -f "$gradle_file" ]]; then
    python3 - "$gradle_file" <<'PY_MIN_SDK'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
content = path.read_text()
content = content.replace("minSdk = flutter.minSdkVersion", "minSdk = 21")
path.write_text(content)
if "minSdk = 21" not in content:
    raise SystemExit("Android configuration validation failed: minSdk must be explicitly set to API 21.")
PY_MIN_SDK
  fi
}

# Preservar Android si está completo. En repositorios con una carpeta android/
# parcial, completar únicamente los archivos que faltan; nunca borrar el directorio.
if [[ -f "$root_dir/android/app/build.gradle.kts" && -f "$root_dir/android/app/src/main/AndroidManifest.xml" && -f "$root_dir/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" && -f "$root_dir/android/app/miltvplus_branding_version.txt" && -f "$root_dir/android/app/miltvplus_signing_configured.txt" && -f "$root_dir/android/app/src/main/res/drawable-nodpi/tv_banner.png" ]]; then
  ensure_min_android_sdk
  echo "El proyecto Android y los recursos de marca están completos; se conservan sin regenerarlos."
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create --platforms=android --project-name miltv_plus --org com.miltvplus "$tmp_dir/miltv-scaffold"
mkdir -p "$root_dir/android"
# -n evita sobrescribir cualquier archivo nativo que ya exista.
cp -Rn "$tmp_dir/miltv-scaffold/android/." "$root_dir/android/"
ensure_min_android_sdk

# Configuración de firma de release opcional. La clave se inyecta solo desde GitHub Actions
# y nunca se almacena en el repositorio. Sin key.properties, Flutter conserva la firma debug
# para builds de desarrollo; las publicaciones por tag exigen una clave de release real.
if [[ ! -f "$root_dir/android/app/miltvplus_signing_configured.txt" ]]; then
  # Kotlin DSL ya define un accessor `java`; importar Properties evita resolver `java.util`
  # contra ese accessor en lugar del paquete Java.
  sed -i '1i import java.util.Properties' "$root_dir/android/app/build.gradle.kts"
  cat >> "$root_dir/android/app/build.gradle.kts" <<'SIGNING_CONFIG'
// MILTVPLUS production signing: enabled only when android/key.properties is present.
val miltvSigningPropertiesFile = rootProject.file("key.properties")
if (miltvSigningPropertiesFile.exists()) {
    val miltvSigningProperties = Properties()
    miltvSigningPropertiesFile.inputStream().use { miltvSigningProperties.load(it) }
    android {
        signingConfigs {
            create("miltvRelease") {
                keyAlias = miltvSigningProperties.getProperty("keyAlias")
                keyPassword = miltvSigningProperties.getProperty("keyPassword")
                storeFile = rootProject.file(miltvSigningProperties.getProperty("storeFile"))
                storePassword = miltvSigningProperties.getProperty("storePassword")
            }
        }
        buildTypes {
            getByName("release") {
                signingConfig = signingConfigs.getByName("miltvRelease")
            }
        }
    }
}
SIGNING_CONFIG
  touch "$root_dir/android/app/miltvplus_signing_configured.txt"
fi

# Recursos visuales propios de MILTVPLUS.
mkdir -p "$root_dir/android/app/src/main/res/drawable"
mkdir -p "$root_dir/android/app/src/main/res/color"
mkdir -p "$root_dir/android/app/src/main/res/values"

mkdir -p "$root_dir/android/app/src/main/res/drawable-nodpi"
python3 - "$root_dir/android/app/src/main/res/drawable-nodpi/tv_banner.png" <<'PY_BANNER'
import struct
import sys
import zlib

width, height = 320, 180
background = (7, 20, 38, 255)
accent = (184, 255, 53, 255)
white = (255, 255, 255, 255)
cyan = (56, 217, 255, 255)
pixels = bytearray(background * (width * height))

def rect(x, y, w, h, color):
    for yy in range(max(0, y), min(height, y + h)):
        for xx in range(max(0, x), min(width, x + w)):
            offset = (yy * width + xx) * 4
            pixels[offset:offset + 4] = bytes(color)

def line(x1, y1, x2, y2, thickness, color):
    dx, dy = abs(x2 - x1), abs(y2 - y1)
    steps = max(dx, dy, 1)
    for i in range(steps + 1):
        x = round(x1 + (x2 - x1) * i / steps)
        y = round(y1 + (y2 - y1) * i / steps)
        rect(x - thickness // 2, y - thickness // 2, thickness, thickness, color)

# TV outline, stand, and play symbol.
rect(24, 54, 62, 48, accent)
rect(30, 60, 50, 36, background)
line(55, 48, 43, 36, 4, accent)
line(55, 48, 67, 36, 4, accent)
rect(48, 103, 14, 6, accent)
rect(39, 110, 32, 5, accent)
for i in range(20):
    rect(46 + i, 67 + i, 1, 1, cyan)
    rect(46 + i, 85 - i, 1, 1, cyan)
# Clear play triangle.
for row in range(19):
    span = max(1, row // 2)
    for xx in range(0, span + 1):
        rect(48 + xx, 66 + row, 1, 1, white)

font = {
'M':("10001","11011","10101","10101","10001","10001","10001"),
'I':("11111","00100","00100","00100","00100","00100","11111"),
'L':("10000","10000","10000","10000","10000","10000","11111"),
'T':("11111","00100","00100","00100","00100","00100","00100"),
'V':("10001","10001","10001","10001","10001","01010","00100"),
'P':("11110","10001","10001","11110","10000","10000","10000"),
'U':("10001","10001","10001","10001","10001","10001","01110"),
'S':("01111","10000","10000","01110","00001","00001","11110"),
}
x, y, scale, gap = 100, 72, 4, 4
for letter in "MILTVPLUS":
    glyph = font[letter]
    for gy, row in enumerate(glyph):
        for gx, bit in enumerate(row):
            if bit == "1":
                rect(x + gx * scale, y + gy * scale, scale, scale, white if letter in "MILTV" else accent)
    x += 5 * scale + gap

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

raw = b"".join(b"\x00" + bytes(pixels[y * width * 4:(y + 1) * width * 4]) for y in range(height))
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw, 9))
png += chunk(b"IEND", b"")
with open(sys.argv[1], "wb") as output:
    output.write(png)
print(f"Banner Android TV generado: {width}x{height}, fondo opaco.")
PY_BANNER

cat > "$root_dir/android/app/src/main/res/values/colors.xml" <<'COLORS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="miltvplus_surface">#111521</color>
    <color name="miltvplus_accent">#B8FF35</color>
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

# Selector para estado presionado: usa el acento de MILTVPLUS con distinta opacidad.
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
# Los IDs del APK de origen se sustituyen por colores semánticos de MILTVPLUS.
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
# Los IDs numéricos del APK original se sustituyen por colores semánticos de MILTVPLUS.
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

# Selectores de estado adicionales adaptados a la paleta y al tema de MILTVPLUS.
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
# Los atributos ?7F0400B7/?7F0400B9 se sustituyen por colores semánticos del tema MILTVPLUS.
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

# Selectores de opacidad, estado marcado y foco para la interfaz MILTVPLUS.
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


# Selectores para foco y selección, adaptados semánticamente a la paleta MILTVPLUS.
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


# Selectores adicionales de foco/selección adaptados a los colores semánticos de MILTVPLUS.
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


# Selectores adicionales adaptados a los estados de foco, selección e interacción.
# Los IDs @7F060xxx pertenecen a la tabla de recursos del APK original; se reemplazan
# por colores semánticos de MILTVPLUS, no por supuestas traducciones de esos IDs.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_accent_surface_selector.xml" <<'FOCUS_ACCENT_SURFACE_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="@color/miltvplus_surface" />
</selector>
FOCUS_ACCENT_SURFACE_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_focus_selected_text_selector.xml" <<'FOCUS_SELECTED_TEXT_SELECTOR'
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
FOCUS_SELECTED_TEXT_SELECTOR

cat > "$root_dir/android/app/src/main/res/color/miltvplus_enabled_pressed_focused_selector.xml" <<'ENABLED_PRESSED_FOCUSED_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary" />
    <item
        android:state_pressed="true"
        android:color="@color/miltvplus_accent" />
    <item
        android:state_focused="true"
        android:color="@color/miltvplus_accent" />
    <item android:color="?android:attr/colorControlNormal" />
</selector>
ENABLED_PRESSED_FOCUSED_SELECTOR


# Animaciones de entrada/salida y curva de interpolación para transiciones Android.
# Los recursos numéricos del APK de origen se sustituyen por duraciones e interpoladores
# explícitos para que la animación sea reproducible dentro del proyecto MILTVPLUS.
mkdir -p "$root_dir/android/app/src/main/res/anim"
mkdir -p "$root_dir/android/app/src/main/res/interpolator"

cat > "$root_dir/android/app/src/main/res/anim/miltvplus_slide_fade_in.xml" <<'SLIDE_FADE_IN'
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:interpolator="@android:interpolator/decelerate_cubic"
    android:duration="250">
    <translate
        android:fromYDelta="20%p"
        android:toYDelta="0%" />
    <alpha
        android:fromAlpha="0.0"
        android:toAlpha="1.0" />
</set>
SLIDE_FADE_IN

cat > "$root_dir/android/app/src/main/res/anim/miltvplus_slide_fade_out.xml" <<'SLIDE_FADE_OUT'
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:interpolator="@android:interpolator/accelerate_cubic"
    android:duration="200">
    <translate
        android:fromYDelta="0%"
        android:toYDelta="20%p" />
    <alpha
        android:fromAlpha="1.0"
        android:toAlpha="0.0" />
</set>
SLIDE_FADE_OUT

cat > "$root_dir/android/app/src/main/res/interpolator/miltvplus_motion_curve.xml" <<'MOTION_CURVE'
<?xml version="1.0" encoding="utf-8"?>
<pathInterpolator xmlns:android="http://schemas.android.com/apk/res/android"
    android:pathData="M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1" />
MOTION_CURVE

cat > "$root_dir/android/app/src/main/res/anim/miltvplus_slide_fade_in_fast.xml" <<'SLIDE_FADE_IN_FAST'
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:interpolator="@android:interpolator/linear_out_slow_in"
    android:duration="250">
    <translate
        android:fromYDelta="20%p"
        android:toYDelta="0%" />
    <alpha
        android:fromAlpha="0.0"
        android:toAlpha="1.0" />
</set>
SLIDE_FADE_IN_FAST

cat > "$root_dir/android/app/src/main/res/anim/miltvplus_slide_fade_out_fast.xml" <<'SLIDE_FADE_OUT_FAST'
<?xml version="1.0" encoding="utf-8"?>
<set xmlns:android="http://schemas.android.com/apk/res/android"
    android:interpolator="@android:interpolator/decelerate_cubic"
    android:duration="200">
    <translate
        android:fromYDelta="0%"
        android:toYDelta="20%p" />
    <alpha
        android:fromAlpha="1.0"
        android:toAlpha="0.0" />
</set>
SLIDE_FADE_OUT_FAST


# Iconos vectoriales de navegación y acciones para MILTVPLUS.
# Se reemplazan las referencias numéricas del APK original por recursos/atributos nombrados.
mkdir -p "$root_dir/android/app/src/main/res/drawable"

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_back.xml" <<'ICON_BACK'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:autoMirrored="true"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M20,11L7.8,11l5.6,-5.6L12,4l-8,8l8,8l1.4,-1.4L7.8,13L20,13L20,11z" />
</vector>
ICON_BACK

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_expand.xml" <<'ICON_EXPAND'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <group
        android:name="arrow"
        android:pivotX="12"
        android:pivotY="12"
        android:rotation="90">
        <path
            android:fillColor="#FF000000"
            android:pathData="M7,14 L12,9 L17,14 L7,14 Z" />
        <path
            android:fillColor="#00000000"
            android:pathData="M0,0 L24,0 L24,24 L0,24 Z" />
    </group>
</vector>
ICON_EXPAND

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_close.xml" <<'ICON_CLOSE'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M19,6.41L17.59,5,12,10.59,6.41,5,5,6.41,10.59,12,5,17.59,6.41,19,12,13.41,17.59,19,19,17.59,13.41,12z" />
</vector>
ICON_CLOSE

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_chevron_right.xml" <<'ICON_CHEVRON_RIGHT'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M10,6l-1.4,1.4 4.6,4.6 -4.6,4.6 1.4,1.4 6,-6z" />
</vector>
ICON_CHEVRON_RIGHT

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_copy.xml" <<'ICON_COPY'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:autoMirrored="true"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M16,1L4,1c-1.1,0 -2,0.9 -2,2v14h2L4,3h12L16,1zM19,5L8,5c-1.1,0 -2,0.9 -2,2v14c0,1.1 0.9,2 2,2h11c1.1,0 2,-0.9 2,-2L21,7c0,-1.1 -0.9,-2 -2,-2zM19,21L8,21L8,7h11v14z" />
</vector>
ICON_COPY

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_tools.xml" <<'ICON_TOOLS'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:autoMirrored="true"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M9.64,7.64c0.23,-0.5 0.36,-1.05 0.36,-1.64 0,-2.21 -1.79,-4 -4,-4S2,3.79 2,6s1.79,4 4,4c0.59,0 1.14,-0.13 1.64,-0.36L10,12l-2.36,2.36C7.14,14.13 6.59,14 6,14c-2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4c0,-0.59 -0.13,-1.14 -0.36,-1.64L12,14l7,7h3v-1L9.64,7.64zM6,8c-1.1,0 -2,-0.89 -2,-2s0.9,-2 2,-2 2,0.89 2,2 -0.9,2 -2,2zM6,20c-1.1,0 -2,-0.89 -2,-2s0.9,-2 2,-2 2,0.89 2,2 -0.9,2 -2,2zM12,12.5c-0.28,0 -0.5,-0.22 -0.5,-0.5s0.22,-0.5 0.5,-0.5 0.5,0.22 0.5,0.5 -0.22,0.5 -0.5,0.5zM19,3l-6,6 2,2 7,-7L22,3z" />
</vector>
ICON_TOOLS

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_more_vertical.xml" <<'ICON_MORE_VERTICAL'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M12,8c1.1,0 2,-0.9 2,-2s-0.9,-2 -2,-2c-1.1,0 -2,0.9 -2,2S10.9,8 12,8zM12,10c-1.1,0 -2,0.9 -2,2s0.9,2 2,2c1.1,0 2,-0.9 2,-2S13.1,10 12,10zM12,16c1.1,0 2,0.9 2,2s-0.9,2 -2,2c-1.1,0 -2,-0.9 -2,-2S10.9,16 12,16z" />
</vector>
ICON_MORE_VERTICAL

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_clipboard.xml" <<'ICON_CLIPBOARD'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M19,2h-4.18C14.4,0.84 13.3,0 12,0c-1.3,0 -2.4,0.84 -2.82,2L5,2c-1.1,0 -2,0.9 -2,2v16c0,1.1 0.9,2 2,2h14c1.1,0 2,-0.9 2,-2L21,4c0,-1.1 -0.9,-2 -2,-2zM12,2c0.55,0 1,0.45 1,1s-0.45,1 -1,1 -1,-0.45 -1,-1 0.45,-1 1,-1zM19,20L5,20L5,4h2v3h10L17,4h2v16z" />
</vector>
ICON_CLIPBOARD

# Iconos adicionales: compartir, buscar y búsqueda por voz.
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_share.xml" <<'ICON_SHARE'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M18,16.08c-0.76,0 -1.44,0.3 -1.96,0.77L8.91,12.7c0.05,-0.23 0.09,-0.46 0.09,-0.7s-0.04,-0.47 -0.09,-0.7l7.05,-4.11c0.54,0.5 1.25,0.81 2.04,0.81 1.66,0 3,-1.34 3,-3s-1.34,-3 -3,-3 -3,1.34 -3,3c0,0.24 0.04,0.47 0.09,0.7L8.04,9.81C7.5,9.31 6.79,9 6,9c-1.66,0 -3,1.34 -3,3s1.34,3 3,3c0.79,0 1.5,-0.31 2.04,-0.81l7.12,4.16c-0.05,0.21 -0.08,0.43 -0.08,0.65 0,1.61 1.31,2.92 2.92,2.92 1.61,0 2.92,-1.31 2.92,-2.92s-1.31,-2.92 -2.92,-2.92z" />
</vector>
ICON_SHARE

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_search.xml" <<'ICON_SEARCH'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M15.5,14h-0.79l-0.28,-0.27C15.41,12.59 16,11.11 16,9.5 16,5.91 13.09,3 9.5,3S3,5.91 3,9.5 5.91,16 9.5,16c1.61,0 3.09,-0.59 4.23,-1.57l0.27,0.28v0.79L19,21.49 20.49,20 15.5,14zM9.5,14C7.01,14 5,11.99 5,9.5S7.01,5 9.5,5 14,7.01 14,9.5 11.99,14 9.5,14z" />
</vector>
ICON_SEARCH

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_mic.xml" <<'ICON_MIC'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="@color/miltvplus_accent">
    <path
        android:fillColor="#FF000000"
        android:pathData="M12,14c1.66,0 3,-1.34 3,-3V5c0,-1.66 -1.34,-3 -3,-3S9,3.34 9,5v6c0,1.66 1.34,3 3,3zM17.3,11c0,3 -2.54,5.1 -5.3,5.1S6.7,14 6.7,11H5c0,3.41 2.72,6.23 6,6.72V21h2v-3.28c3.28,-0.49 6,-3.31 6,-6.72h-1.7z" />
</vector>
ICON_MIC

# Fondos y selectores de foco/hover para controles de MILTVPLUS.
# Los recursos numéricos del APK decompilado no se pueden identificar sin su tabla original.
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_shape_focus_glow.xml" <<'FOCUS_GLOW'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#88FFFFFF" />
</shape>
FOCUS_GLOW

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_shape_surface_rounded.xml" <<'SURFACE_ROUNDED'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="@color/miltvplus_surface" />
    <corners android:radius="4dp" />
</shape>
SURFACE_ROUNDED

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_shape_accent_rounded.xml" <<'ACCENT_ROUNDED'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="@color/miltvplus_accent" />
    <corners android:radius="4dp" />
</shape>
ACCENT_ROUNDED

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_selector_focus_hover_background.xml" <<'SELECTOR_FOCUS_HOVER'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item
        android:state_hovered="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item android:drawable="@drawable/miltvplus_shape_surface_rounded" />
</selector>
SELECTOR_FOCUS_HOVER

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_selector_focused_background.xml" <<'SELECTOR_FOCUSED'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item android:drawable="@drawable/miltvplus_shape_surface_rounded" />
</selector>
SELECTOR_FOCUSED

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_selector_focus_hover_surface.xml" <<'SELECTOR_FOCUS_HOVER_SURFACE'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item
        android:state_hovered="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item android:drawable="@color/miltvplus_surface" />
</selector>
SELECTOR_FOCUS_HOVER_SURFACE

cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_selector_focus_selected_background.xml" <<'SELECTOR_FOCUS_SELECTED'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_focused="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item
        android:state_selected="true"
        android:drawable="@drawable/miltvplus_shape_accent_rounded" />
    <item android:drawable="@drawable/miltvplus_shape_surface_rounded" />
</selector>
SELECTOR_FOCUS_SELECTED

# Gradiente de sombra y vector de marca para recursos de MILTVPLUS.
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_gradient_shadow.xml" <<'GRADIENT_SHADOW'
<?xml version="1.0" encoding="utf-8"?>
<gradient xmlns:android="http://schemas.android.com/apk/res/android"
    android:angle="135"
    android:type="linear"
    android:startColor="#44000000"
    android:endColor="#00000000" />
GRADIENT_SHADOW

# Icono vectorial Android estilo robot genérico; reemplaza el ID de color privado del XML original.
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_ic_platform_robot.xml" <<'PLATFORM_ROBOT'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <!-- Keep the complete mark inside the adaptive-icon safe zone. -->
    <group
        android:pivotX="54"
        android:pivotY="54"
        android:scaleX="0.78"
        android:scaleY="0.78">
        <!-- Cyan edge behind the brand-green outline creates a crisp neon accent. -->
        <path
            android:fillColor="#00000000"
            android:strokeColor="#FF38D9FF"
            android:strokeWidth="3.8"
            android:strokeLineCap="round"
            android:strokeLineJoin="round"
            android:pathData="M39,24 L31,16 M69,24 L77,16 M25,27 L83,27 C87.4,27 91,30.6 91,35 L91,69 C91,73.4 87.4,77 83,77 L25,77 C20.6,77 17,73.4 17,69 L17,35 C17,30.6 20.6,27 25,27 Z" />
        <path
            android:fillColor="#071426"
            android:strokeColor="#B8FF35"
            android:strokeWidth="3.5"
            android:strokeLineJoin="round"
            android:pathData="M25,27 L83,27 C87.4,27 91,30.6 91,35 L91,69 C91,73.4 87.4,77 83,77 L25,77 C20.6,77 17,73.4 17,69 L17,35 C17,30.6 20.6,27 25,27 Z" />
        <path
            android:fillColor="#FFFFFF"
            android:pathData="M44,39.5 C44,38.7 44.9,38.2 45.6,38.7 L67,51.3 C67.9,51.8 67.9,53.2 67,53.7 L45.6,66.3 C44.9,66.8 44,66.3 44,65.5 Z" />
        <path
            android:fillColor="#B8FF35"
            android:pathData="M39,81 L69,81 L74,87 L34,87 Z M45,89 L63,89 L63,93 L45,93 Z" />
        <path
            android:fillColor="#38D9FF"
            android:pathData="M77,39 L81,39 L81,43 L77,43 Z" />
    </group>
</vector>
PLATFORM_ROBOT

# Icono adaptativo propio de MILTVPLUS (Android 8.0+).
# Se reemplazan las referencias numéricas del APK de origen por recursos locales.
mkdir -p "$root_dir/android/app/src/main/res/mipmap-anydpi-v26"
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_icon_background.xml" <<'ICON_BACKGROUND'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#071426" />
</shape>
ICON_BACKGROUND

cat > "$root_dir/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<'ADAPTIVE_ICON'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/miltvplus_icon_background" />
    <foreground android:drawable="@drawable/miltvplus_ic_platform_robot" />
</adaptive-icon>
ADAPTIVE_ICON

cat > "$root_dir/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml" <<'ADAPTIVE_ICON_ROUND'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/miltvplus_icon_background" />
    <foreground android:drawable="@drawable/miltvplus_ic_platform_robot" />
</adaptive-icon>
ADAPTIVE_ICON_ROUND

# Selector equivalente al XML recibido: estado deshabilitado atenuado y estado normal con acento.
# Los atributos ?01010038 y ?7F0400B4 del APK decompilado no son portables entre proyectos.
cat > "$root_dir/android/app/src/main/res/color/miltvplus_enabled_accent_selector.xml" <<'ENABLED_ACCENT_SELECTOR'
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item
        android:state_enabled="false"
        android:color="?android:attr/textColorSecondary"
        android:alpha="?android:attr/disabledAlpha" />
    <item android:color="@color/miltvplus_accent" />
</selector>
ENABLED_ACCENT_SELECTOR

# Fondo redondeado con gradiente de marca, adaptado del XML de referencia.
# Los IDs de color numéricos del APK original no son portables; se usan colores MILTVPLUS.
cat > "$root_dir/android/app/src/main/res/drawable/miltvplus_shape_brand_gradient.xml" <<'BRAND_GRADIENT'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="7dp" />
    <gradient
        android:startColor="@color/miltvplus_accent"
        android:endColor="@color/miltvplus_surface"
        android:angle="0" />
</shape>
BRAND_GRADIENT

# Android TV / TV Box y móviles: manifiesto para MILTVPLUS.
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
    <!-- Required so the in-app OTA can hand the downloaded APK to the system installer. -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />

    <application
        android:name="${applicationName}"
        android:label="MILTVPLUS"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
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

# Iconos legacy de launcher para Android anterior a los iconos adaptativos (API 25 y anteriores).
# Se generan con Python estándar para que la compilación no dependa de Pillow/ImageMagick.
python3 - "$root_dir/android/app/src/main/res" <<'PY_ICON'
import os
import struct
import sys
import zlib

res = sys.argv[1]
size = 576
background = (7, 20, 38, 255)
accent = (184, 255, 53, 255)
cyan = (56, 217, 255, 255)
white = (255, 255, 255, 255)
pixels = bytearray(background * (size * size))

def put(x, y, color):
    if 0 <= x < size and 0 <= y < size:
        offset = (y * size + x) * 4
        pixels[offset:offset + 4] = bytes(color)

def rect(x, y, w, h, color):
    for yy in range(max(0, y), min(size, y + h)):
        start = (yy * size + max(0, x)) * 4
        end = (yy * size + min(size, x + w)) * 4
        if end > start:
            pixels[start:end] = bytes(color) * ((end - start) // 4)

def circle(cx, cy, radius, color):
    r2 = radius * radius
    for yy in range(max(0, cy - radius), min(size, cy + radius + 1)):
        dy = yy - cy
        for xx in range(max(0, cx - radius), min(size, cx + radius + 1)):
            dx = xx - cx
            if dx * dx + dy * dy <= r2:
                put(xx, yy, color)

def rounded_rect(x, y, w, h, radius, color):
    rect(x + radius, y, w - 2 * radius, h, color)
    rect(x, y + radius, w, h - 2 * radius, color)
    circle(x + radius, y + radius, radius, color)
    circle(x + w - radius - 1, y + radius, radius, color)
    circle(x + radius, y + h - radius - 1, radius, color)
    circle(x + w - radius - 1, y + h - radius - 1, radius, color)

def line(x1, y1, x2, y2, thickness, color):
    steps = max(abs(x2 - x1), abs(y2 - y1), 1)
    radius = max(1, thickness // 2)
    for i in range(steps + 1):
        x = round(x1 + (x2 - x1) * i / steps)
        y = round(y1 + (y2 - y1) * i / steps)
        rect(x - radius, y - radius, thickness, thickness, color)

def triangle(points, color):
    (x1, y1), (x2, y2), (x3, y3) = points
    ymin, ymax = min(y1, y2, y3), max(y1, y2, y3)
    for y in range(ymin, ymax + 1):
        intersections = []
        for (ax, ay), (bx, by) in (((x1, y1), (x2, y2)), ((x2, y2), (x3, y3)), ((x3, y3), (x1, y1))):
            if ay == by or y < min(ay, by) or y >= max(ay, by):
                continue
            intersections.append(round(ax + (y - ay) * (bx - ax) / (by - ay)))
        if len(intersections) >= 2:
            rect(min(intersections), y, max(intersections) - min(intersections) + 1, 1, color)

# Futuristic TV silhouette, antennae, high-contrast screen, play symbol, and stand.
line(228, 180, 176, 124, 15, cyan)
line(348, 180, 400, 124, 15, cyan)
circle(174, 122, 12, accent)
circle(402, 122, 12, accent)
rounded_rect(104, 176, 368, 238, 42, accent)
rounded_rect(132, 204, 312, 182, 26, (3, 11, 22, 255))
triangle([(244, 236), (244, 354), (346, 295)], white)
rounded_rect(260, 410, 56, 42, 10, accent)
rounded_rect(208, 448, 160, 28, 12, accent)
rounded_rect(154, 332, 16, 16, 6, cyan)
rounded_rect(406, 332, 16, 16, 6, cyan)

def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

def write_png(path, target):
    # Every target size divides 576; nearest-neighbour scaling keeps the logo crisp.
    scale = size // target
    raw = bytearray()
    for y in range(target):
        raw.append(0)
        for x in range(target):
            source = ((y * scale) * size + x * scale) * 4
            raw.extend(pixels[source:source + 4])
    data = b"\x89PNG\r\n\x1a\n"
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", target, target, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    data += png_chunk(b"IEND", b"")
    with open(path, "wb") as output:
        output.write(data)

for density, target in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    folder = os.path.join(res, "mipmap-" + density)
    os.makedirs(folder, exist_ok=True)
    write_png(os.path.join(folder, "ic_launcher.png"), target)
    write_png(os.path.join(folder, "ic_launcher_round.png"), target)

with open(os.path.join(os.path.dirname(res), "miltvplus_branding_version.txt"), "w", encoding="utf-8") as marker:
    marker.write("MILTVPLUS launcher branding v1\n")
print("Iconos de launcher MILTVPLUS generados para mdpi, hdpi, xhdpi, xxhdpi y xxxhdpi.")
PY_ICON

# Branded native launch background: gradient base plus the same safe-zone logo.
# Flutter's animated SplashScreen takes over after the first frame; this avoids a generic
# platform splash during engine startup. The vector stays crisp at different densities.
mkdir -p "$root_dir/android/app/src/main/res/drawable-v21"
cat > "$root_dir/android/app/src/main/res/drawable/launch_background.xml" <<'NATIVE_SPLASH'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <gradient
                android:angle="135"
                android:startColor="#10262F"
                android:centerColor="#101725"
                android:endColor="#070B12"
                android:type="linear" />
        </shape>
    </item>
    <item
        android:drawable="@drawable/miltvplus_ic_platform_robot"
        android:gravity="center" />
</layer-list>
NATIVE_SPLASH
cp "$root_dir/android/app/src/main/res/drawable/launch_background.xml" "$root_dir/android/app/src/main/res/drawable-v21/launch_background.xml"

echo "Estructura Android generada con selectores de color MILTVPLUS y manifiesto para móviles, Android TV y TV Box."
echo "Siguiente paso: ejecutar flutter pub get, flutter analyze y las pruebas del proyecto."
