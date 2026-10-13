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


# Selectores adicionales adaptados a los estados de foco, selección e interacción.
# Los IDs @7F060xxx pertenecen a la tabla de recursos del APK original; se reemplazan
# por colores semánticos de MILTV PLUS, no por supuestas traducciones de esos IDs.
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
# explícitos para que la animación sea reproducible dentro del proyecto MILTV PLUS.
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


# Iconos vectoriales de navegación y acciones para MILTV PLUS.
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

# Fondos y selectores de foco/hover para controles de MILTV PLUS.
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

# Gradiente de sombra y vector de marca para recursos de MILTV PLUS.
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
    <path
        android:fillColor="@color/miltvplus_accent"
        android:pathData="M31,63.928c0,0 6.4,-11 12.1,-13.1c7.2,-2.6 26,-1.4 26,-1.4l38.1,38.1L107,108.928l-32,-1L31,63.928z" />
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M65.3,45.828l3.8,-6.6c0.2,-0.4 0.1,-0.9 -0.3,-1.1c-0.4,-0.2 -0.9,-0.1 -1.1,0.3l-3.9,6.7c-6.3,-2.8 -13.4,-2.8 -19.7,0l-3.9,-6.7c-0.2,-0.4 -0.7,-0.5 -1.1,-0.3C38.8,38.328 38.7,38.828 38.9,39.228l3.8,6.6C36.2,49.428 31.7,56.028 31,63.928h46C76.3,56.028 71.8,49.428 65.3,45.828zM43.4,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2c-0.3,-0.7 -0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C45.3,56.528 44.5,57.328 43.4,57.328L43.4,57.328zM64.6,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2s-0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C66.5,56.528 65.6,57.328 64.6,57.328z" />
</vector>
PLATFORM_ROBOT

# Icono adaptativo propio de MILTV PLUS (Android 8.0+).
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
