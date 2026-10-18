# Sincronización de metadatos TMDB — QA

La función `supabase/functions/sync-tmdb-catalog/index.ts` importa títulos, sinopsis, géneros y pósteres de películas y series populares desde TMDB. No descarga ni crea enlaces de reproducción.

## Configuración exclusivamente en QA

1. Desplegá la migración `20261015150000_tmdb_catalog_sync.sql` en Supabase.
2. En Supabase, configurá los secretos de la Edge Function:
   - `TMDB_API_KEY`: clave de API de TMDB.
   - `SYNC_SECRET`: secreto largo y aleatorio compartido únicamente con el job de sincronización.
3. Desplegá la función `sync-tmdb-catalog`.
4. En GitHub Actions > Settings > Secrets and variables > Actions, configurá:
   - `SUPABASE_URL`: URL del proyecto Supabase.
   - `SUPABASE_ANON_KEY`: clave pública anon/publishable del proyecto (nunca la service_role).
   - `MILTVPLUS_CATALOG_SYNC_SECRET`: el mismo valor que el secreto `SYNC_SECRET` de la función.
5. En QA, ejecutá la función con POST y el encabezado `x-sync-secret` desde un entorno seguro. No actives una sincronización contra producción para validar estos cambios.

## Seguridad y publicación

- La función exige `x-sync-secret`; no coloques ese secreto en Flutter, en el APK ni en el repositorio.
- La función usa `SUPABASE_SERVICE_ROLE_KEY` solo desde los secretos de Supabase.
- Los registros de metadatos de películas se crean con `url_stream = ''`. Se muestran en el catálogo, pero la app debe impedir reproducirlos hasta que el propietario añada un enlace autorizado.
- La sincronización es idempotente mediante `tmdb_id`: una ejecución posterior actualiza metadatos en lugar de duplicar filas.
- TMDB aporta metadatos, no derechos de distribución ni URLs de streaming. Revisá los términos de TMDB y configurá la atribución que corresponda antes de publicar.
- La función procesa lotes de hasta 20 páginas por invocación, con `startPage` entre 1 y 500. Por ejemplo, usar `{"startPage":1,"pages":20}`, luego `{"startPage":21,"pages":20}`, y continuar con 41, 61, etc. hasta cubrir las páginas disponibles. La respuesta incluye `moviePagesAvailable` y `seriesPagesAvailable` para conocer el total que informa TMDB.
- El límite de 500 páginas corresponde al API de TMDB y no equivale a un inventario universal completo; son resultados del catálogo de TMDB y pueden cambiar.
- Para series, esta función sincroniza títulos/metadatos, no temporadas, episodios ni sus streams.
- Antes de declarar el catálogo listo, contrastá conteos, páginas disponibles y filas sin URL de reproducción. La cobertura de metadatos no significa que el contenido sea reproducible.
