# MILTVPLUS

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
En TV EN VIVO, abrí **FUENTES DE TV** para importar listas públicas por país, idioma o categoría (Argentina, español, noticias, deportes, canales de películas, canales de series, documentales, infantiles y música), además de las listas global y curada. También podés importar una URL M3U propia o autorizada. Los canales se combinan sin duplicar URLs y se guardan localmente.

Una lista M3U de “canales de películas” o “canales de series” contiene canales lineales en vivo; **no** equivale a un catálogo bajo demanda tipo Netflix. La sección de películas/series consume metadatos y URLs publicados en las tablas `movies`, `series` y `episodes` de Supabase. Para incorporar un proveedor privado de VOD hace falta su endpoint/API o un formato de exportación autorizado, la estructura de autenticación y los campos de catálogo/episodios. No se deben pegar contraseñas, tokens ni claves privadas en el código o en el repositorio. No se encontró una URL privada de proveedor en los archivos consultados, por lo que no se inventaron endpoints ni enlaces.

## Sección +18
La primera vez se configura un PIN de 4 a 8 dígitos; en accesos posteriores se valida. El PIN no se guarda en texto plano. Este control es local a la app y no reemplaza los controles parentales del dispositivo.

## Compilación APK
El workflow `.github/workflows/build.yml` se ejecuta en cada push a `main` o manualmente desde **GitHub → Actions**. Al finalizar, el APK aparece como artefacto `MILTVPLUS-release-apk`. La compilación solo se considera verificada cuando el workflow termina correctamente.


## Compatibilidad objetivo (plan de producto)

- **Primera plataforma verificable:** Android móvil y tablet, APK.
- **Pantalla grande:** Android TV, Google TV y Android TV Box, con navegación completa por control remoto (DPAD), foco visible y diseño horizontal.
- **Amazon Fire TV:** objetivo condicionado a pruebas reales de instalación, foco y reproducción.
- **iPhone/iPad, Apple TV, Samsung Tizen, LG webOS y Roku:** no quedan cubiertos por el APK Android; requieren aplicaciones nativas o una experiencia web compatible separada.
- **Formatos de reproducción previstos:** HLS (.m3u8) y MP4 cuando el códec sea compatible con el dispositivo; subtítulos y pistas de audio dependen del formato y del reproductor.
- **Catálogo:** conectar únicamente fuentes propias o licenciadas. No se incluyen películas, canales ni enlaces de terceros sin autorización.

## Estado real y próximos hitos

Esta rama es una base funcional en desarrollo, no una copia completa de otra plataforma. Las pantallas de catálogo y TV en vivo necesitan validación integral con datos autorizados y dispositivos reales. Antes de distribuir una versión se deben pasar análisis, pruebas automatizadas, build APK, pruebas táctiles y pruebas con mando en Android TV. La compatibilidad no se considera confirmada hasta superar esas pruebas.
