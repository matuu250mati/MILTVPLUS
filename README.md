# MILTV PLUS

Aplicación de entretenimiento desarrollada con Flutter, con identidad visual original y navegación adaptada a celulares, Android TV y TV Box compatibles.

## Incluye
- Intro animada y navegación lateral retráctil.
- Secciones TV EN VIVO, DESTACADOS, PELÍCULAS, SERIES, ANIME y EXPLORAR.
- Reproductor HLS configurable con lista lateral de canales.
- Catálogos visuales de ejemplo, listos para conectar a un proveedor de contenido.
- Sección +18 protegida por PIN numérico con hash guardado mediante almacenamiento seguro.
- GitHub Actions para análisis, tests y generación de APK release.

## Preparar Android localmente
Requisitos: Flutter stable, Android SDK y Java 17.

Como el repositorio genera los archivos nativos con la versión de Flutter disponible, ejecutá:

```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter run
```

El script genera la carpeta `android/` con Flutter stable y aplica el manifiesto para móviles, Android TV y TV Box. El workflow de GitHub Actions usa el mismo procedimiento en un runner limpio.

## TV en vivo
En TV EN VIVO, usá **AGREGAR** e ingresá un nombre y una URL HTTP(S) HLS válida (normalmente `.m3u8`). Se deben usar únicamente fuentes propias o autorizadas. La lista de canales de esta primera versión se mantiene en memoria y se reinicia al cerrar la app.

## Sección +18
La primera vez se configura un PIN de 4 a 8 dígitos; en accesos posteriores se valida. El PIN no se guarda en texto plano. Este control es local a la app y no reemplaza los controles parentales del dispositivo.

## Compilación APK
El workflow `.github/workflows/build.yml` se ejecuta en cada push a `main` o manualmente desde **GitHub → Actions**. Al finalizar, el APK aparece como artefacto `MILTVPLUS-release-apk`. La compilación solo se considera verificada cuando el workflow termina correctamente.
