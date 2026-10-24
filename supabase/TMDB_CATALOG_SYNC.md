# Sincronización de metadatos TMDB

La Edge Function `sync-tmdb-catalog` importa metadatos (títulos, sinopsis, géneros y pósteres) desde TMDB. No descarga ni inventa enlaces de reproducción. Las películas importadas quedan con `url_stream = ''` hasta que el propietario añada una URL autorizada.

## Entorno QA (único destino del workflow automático)

El workflow `.github/workflows/sync-tmdb-catalog.yml` usa el entorno de GitHub Actions `miltvplus-qa` y debe apuntar únicamente al proyecto Supabase QA. No uses secretos de producción en este workflow.

GitHub Actions necesita los siguientes secretos, disponibles en el entorno `miltvplus-qa` o como secretos de repositorio con esos nombres:

- `SUPABASE_QA_URL`: URL raíz del proyecto QA, con formato `https://<project-ref>.supabase.co`.
- `SUPABASE_QA_ANON_KEY`: clave pública anon/publishable del mismo proyecto QA.
- `SUPABASE_QA_ACCESS_TOKEN`: token personal de Supabase autorizado para desplegar la función en QA.
- `MILTVPLUS_QA_CATALOG_SYNC_SECRET`: secreto largo y aleatorio para autenticar la solicitud del workflow.

En el proyecto **Supabase QA**, abrí **Edge Functions → Secrets** y configurá también:

- `TMDB_API_KEY`: clave API de TMDB.
- `SYNC_SECRET`: debe ser exactamente el mismo valor que `MILTVPLUS_QA_CATALOG_SYNC_SECRET` de GitHub Actions.
- `SUPABASE_SERVICE_ROLE_KEY`: service-role key del propio proyecto QA. Debe permanecer únicamente en los secretos del servidor Supabase; nunca en Flutter, APK, commits ni logs.

### Diagnóstico y recuperación de errores de sincronización

Una ejecución anterior del 23/10/2026 devolvió HTTP 401 con `{"error":"Unauthorized catalog sync request."}`, porque el secreto de ejecución de la Edge Function no coincidía con el encabezado `x-sync-secret`.

El workflow actual de GitHub Actions incluye un paso previo que configura el secreto de runtime `SYNC_SECRET` en el proyecto QA usando el valor de `MILTVPLUS_QA_CATALOG_SYNC_SECRET` del entorno de GitHub `miltvplus-qa`, y luego vuelve a desplegar la función. Por eso, no hace falta copiar manualmente ese mismo secreto a Supabase si el workflow puede autenticarse y desplegar correctamente. No imprimas ni compartas el valor del secreto.

Para validar la recuperación, ejecutá **Actions → Sync TMDB catalog metadata → Run workflow** con `pages=1`. La ejecución solo se considera correcta si termina con HTTP 2xx y `"ok":true`, y muestra conteos de metadatos procesados.

Si devuelve HTTP 401, confirmá que `MILTVPLUS_QA_CATALOG_SYNC_SECRET` existe en el entorno `miltvplus-qa` y que el paso **Align QA Edge Function sync secret** se ejecutó en el proyecto QA correcto. Si devuelve HTTP 500, verificá en **Supabase QA → Edge Functions → Secrets** que existan `TMDB_API_KEY` y `SUPABASE_SERVICE_ROLE_KEY` para ese mismo proyecto. Nunca compartas esos valores. Si falla antes de invocar la función, revisá los secretos de GitHub QA y los permisos del token de acceso.

## Despliegue de la función

`.github/workflows/deploy-tmdb-catalog-function.yml` es manual y está limitado al entorno `miltvplus-qa`. No debe desplegarse automáticamente a Producción. El workflow de sincronización también despliega la función al proyecto QA que obtiene de `SUPABASE_QA_URL` antes de hacer la llamada.

## Seguridad y datos

- La función exige la cabecera `x-sync-secret`; no guardes ese secreto en Flutter ni en el APK.
- La función usa `SUPABASE_SERVICE_ROLE_KEY` solo del entorno servidor de Supabase.
- La sincronización es idempotente por `tmdb_id): las ejecuciones posteriores actualizan metadatos en lugar de duplicar filas.
- TMDB aporta metadatos, no derechos de distribución ni URLs de streaming. Revisá sus términos y la atribución correspondiente antes de publicar.
- La función acepta de 1 a 5 páginas por ejecución. Empezá con 1 página durante la validación para limitar el consumo y el volumen de cambios.

## Episodios y fuentes existentes

La función también importa temporadas y episodios (solo metadatos) de las series sincronizadas.

- Opciones del cuerpo JSON: `includeEpisodes` (por defecto `true`) y `episodeSeriesLimit` (por defecto 5, máximo 20 series por página, para no superar el tiempo límite de la Edge Function).
- La respuesta incluye `episodesProcessed`.
- Las películas y episodios nuevos se crean con `url_stream` vacío: no son reproducibles hasta que el propietario cargue una fuente autorizada.
- Las películas y episodios que ya existen solo reciben metadatos: sus `url_stream` y duraciones no se sobrescriben.
