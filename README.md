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

## Propuestas de contenido

La opción PUBLICAR permite a usuarios autenticados proponer películas o episodios con título, descripción, duración y URL de reproducción. Cada envío queda pendiente y no se publica automáticamente. Aplicá `supabase/migrations/20261013090200_user_content_submissions.sql` en el SQL Editor de Supabase. Un moderador debe verificar los derechos y la seguridad del enlace antes de publicar el contenido en el catálogo.

## Catálogo VOD y reproducción

- Las tarjetas de películas abren el reproductor nativo cuando el registro publicado tiene `url_stream`.
- Las tarjetas de series consultan `episodes`, muestran temporada/episodio y abren el reproductor con la URL del episodio publicado.
- El reproductor valida URLs HTTPS (el tráfico HTTP sin cifrar está bloqueado por seguridad en Android), inicializa `video_player`, ofrece reintento y muestra errores de reproducción sin simular que el título se reprodujo.
- Para que el catálogo tenga títulos reales, el proveedor autorizado debe publicar metadatos y URLs de reproducción en Supabase: `movies`, `series` y `episodes`. La app no inventa títulos ni extrae catálogos privados sin un endpoint/configuración proporcionados.

## Estado real y próximos hitos

Se conectaron las acciones de reproducción de películas y episodios al reproductor. Eso no implica que ya existan títulos publicados ni que las URLs del proveedor estén activas. Antes de distribuir una versión se deben pasar `flutter analyze`, `flutter test`, build APK y pruebas de reproducción con fuentes autorizadas en el dispositivo objetivo. La compilación y la reproducción no se consideran confirmadas hasta superar esas pruebas.


## Supabase: acceso al catálogo publicado

La guía de configuración de la base de datos, roles de moderación y pruebas de aceptación está en [`supabase/SETUP_ES.md`](supabase/SETUP_ES.md).

Si se ejecuta el SQL inicial en un proyecto que ya tiene tablas creadas, aplicá también
`supabase/migrations/20261013090000_public_published_catalog.sql` desde el SQL Editor de Supabase.
La migración permite leer solo filas publicadas de `movies` y `series` para usuarios
anónimos y autenticados, necesario para explorar el catálogo sin iniciar sesión. No agrega
políticas de escritura desde la app. Las URLs de reproducción solo deben publicarse cuando
se tenga autorización para distribuir ese contenido.

## Publicación de APK y descarga estable

El workflow de Android genera el APK de release, un archivo SHA-256 y artefactos de compilación. Para publicar una versión permanente:

1. Actualizá `version:` en `pubspec.yaml` (por ejemplo, `1.0.0+1`).
2. Confirmá que las comprobaciones de Flutter y la compilación Android estén verdes.
3. Creá y subí un tag que coincida con la versión pública, sin el sufijo de build: por ejemplo, `v1.0.0`.
4. El workflow valida que el tag coincida con `pubspec.yaml`, vuelve a analizar/probar/compilar y publica el APK junto con sus checksums en GitHub Releases.

Antes de publicar el primer tag, configurá una clave de firma de producción estable. Generala en un equipo/entorno privado (no en el repositorio) con:

```bash
keytool -genkeypair -v -keystore miltvplus-upload.jks -alias miltvplus -keyalg RSA -keysize 2048 -validity 10000
base64 -w 0 miltvplus-upload.jks
```

Guardá la salida Base64 y los valores de la clave en **Settings → Secrets and variables → Actions** como `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`. El workflow solo publica tags si estos cuatro secretos están configurados y la clave se puede validar. No subas el archivo `.jks` ni contraseñas al repositorio. Conservá una copia de seguridad privada de la clave: las futuras actualizaciones Android deben firmarse con la misma clave.

La URL estable prevista para el sitio oficial es:

`https://github.com/matuu250mati/MILTVPLUS/releases/latest/download/MILTVPLUS-android.apk`

También se publica una copia con versión en el nombre del archivo. El checksum SHA-256 permite comprobar que el APK descargado no se alteró durante la transferencia.

**Downloader:** el código numérico de Downloader no se puede inventar ni generar solo desde el APK. Primero hay que publicar y probar la URL definitiva; luego se crea el código con el servicio de acortamiento compatible con Downloader y se verifica desde un dispositivo real. El sitio debe apuntar a la URL estable anterior o a una redirección bajo el dominio oficial.

El enlace estable solo estará disponible después de publicar el primer tag de versión; los artefactos de Actions son temporales y se conservan 14 días.

