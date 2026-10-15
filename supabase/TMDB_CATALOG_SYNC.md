# Sincronización de metadatos TMDB

La función `supabase/functions/sync-tmdb-catalog/index.ts` importa títulos, sinopsis, géneros y pósteres de películas y series populares desde TMDB. No descarga ni crea enlaces de reproducción.

## Configuración de producción

1. Desplegá la migración `20261015150000_tmdb_catalog_sync.sql` en Supabase.
2. En Supabase, configurá los secretos de la Edge Function:
   - `TMDB_API_KEY`: clave de API de TMDB.
   - `SYNC_SECRET`: secreto largo y aleatorio compartido únicamente con el job de sincronización.
3. Desplegá la función `sync-tmdb-catalog`.
4. En GitHub Actions > Settings > Secrets and variables > Actions, configurá:
   - `SUPABASE_URL`: URL del proyecto Supabase.
   - `SUPABASE_ANON_KEY`: clave pública anon/publishable del proyecto (nunca la service_role).
   - `MILTVPLUS_CATALOG_SYNC_SECRET`: el mismo valor que el secreto `SYNC_SECRET` de la función.
5. Ejecutá manualmente el workflow `Sync TMDB catalog metadata` para la primera sincronización. También corre diariamente por cron.

## Seguridad y publicación

- La función exige `x-sync-secret`; no coloques ese secreto en Flutter, en el APK ni en el repositorio.
- La función usa `SUPABASE_SERVICE_ROLE_KEY` solo desde los secretos de Supabase.
- Los registros de metadatos de películas se crean con `url_stream = ''`. Se muestran en el catálogo, pero la app debe impedir reproducirlos hasta que el propietario añada un enlace autorizado.
- La sincronización es idempotente mediante `tmdb_id`: una ejecución posterior actualiza metadatos en lugar de duplicar filas.
- TMDB aporta metadatos, no derechos de distribución ni URLs de streaming. Revisá los términos de TMDB y configurá la atribución que corresponda antes de publicar.
- La función procesa una página por defecto y acepta de 1 a 5 páginas por ejecución. Para limitar consumo y evitar sobrecargar la base, no la llames en bucles frecuentes.
