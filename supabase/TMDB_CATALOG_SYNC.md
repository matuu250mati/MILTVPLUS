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

### Diagnóstico del HTTP 401

La ejecución de GitHub Actions del 23/10/2026 desplegó correctamente la función al proyecto configurado como QA, pero la llamada devolvió:

```json
{"error":"Unauthorized catalog sync request."}
```

Ese texto lo devuelve el código de la propia Edge Function cuando `SYNC_SECRET` falta o no coincide exactamente con la cabecera `x-sync-secret`. Por tanto, el fallo observado está en la correspondencia del secreto de sincronización, no en la compilación ni en la instalación de Supabase CLI.

Para corregirlo, copiá el mismo secreto generado en GitHub (`MILTVPLUS_QA_CATALOG_SYNC_SECRET`) al secreto `SYNC_SECRET` de **Supabase QA**. No lo pegues en el chat ni lo imprimas en logs. Luego ejecutá manualmente **Actions → Sync TMDB catalog metadata → Run workflow** con 1 página para la primera comprobación. La ejecución solo se considera correcta si termina con HTTP 2xx y `"ok":true`.

Un HTTP 500 posterior indicaría que falta algún secreto de runtime (normalmente `TMDB_API_KEY`, `SYNC_SECRET` o `SUPABASE_SERVICE_ROLE_KEY`) o que la función no puede escribir en el esquema. Revisá el error sin compartir valores secretos.

## Despliegue de la función

`.github/workflows/deploy-tmdb-catalog-function.yml` es manual y está limitado al entorno `miltvplus-qa`. No debe desplegarse automáticamente a Producción. El workflow de sincronización también despliega la función al proyecto QA que obtiene de `SUPABASE_QA_URL` antes de hacer la llamada.

## Seguridad y datos

- La función exige la cabecera `x-sync-secret`; no guardes ese secreto en Flutter ni en el APK.
- La función usa `SUPABASE_SERVICE_ROLE_KEY` solo del entorno servidor de Supabase.
- La sincronización es idempotente por `tmdb_id): las ejecuciones posteriores actualizan metadatos en lugar de duplicar filas.
- TMDB aporta metadatos, no derechos de distribución ni URLs de streaming. Revisá sus términos y la atribución correspondiente antes de publicar.
- La función acepta de 1 a 5 páginas por ejecución. Empezá con 1 página durante la validación para limitar el consumo y el volumen de cambios.
