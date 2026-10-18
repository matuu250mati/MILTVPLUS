# Sincronización M3U de MILTVPLUS — QA

Esta función es exclusivamente para canales lineales y escribe solo en `public.channels`. No inserta canales temáticos como películas VOD ni como series/episodios.

## Qué se ha corregido en esta versión QA

- Conserva las 14 fuentes configuradas y sustituye la fuente específica de México por el índice global de IPTV-org para ampliar la cobertura internacional; la fuente de Argentina y las fuentes de categorías se mantienen.
- Elimina el límite fijo de 5.000 filas por ejecución.
- Mantiene membresías por categoría: el mismo canal puede aparecer en la lista de Deportes y en la de su país sin que una entrada sobrescriba la otra.
- Importa por lotes de 100 y conserva filas manuales existentes.
- Informa por fuente `fetched`, `parsed`, `accepted`, `deduplicated`, `rejected` y los errores de descarga. `complete` solo será `true` cuando todas las fuentes respondan y no se haya rechazado ninguna entrada. Una respuesta HTTP 207 significa que la sincronización requiere revisión; no se debe declarar completa.
- Solo acepta URLs HTTPS directas cuyo path termine en `.m3u8`. Las entradas descartadas por ese filtro y las señales que estén caídas siguen siendo una limitación que debe medirse; la importación no prueba cada stream.

## Despliegue exclusivamente en QA

1. Revisá el esquema del proyecto **MILTVPLUS-QA** y hacé copia de seguridad antes de cambios de base.
2. Aplicá `supabase/migrations/20261018130000_m3u_catalog_sync_qa.sql` únicamente en QA.
3. Desplegá `supabase/functions/sync-m3u-catalog/index.ts` como Edge Function en el mismo proyecto QA.
4. Configurá `SYNC_SECRET` en los secretos de la función. La función también requiere los secretos de servidor `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`; nunca se deben incluir en Flutter ni en Git.
5. Invocá la función con POST y el encabezado `x-sync-secret` desde un entorno seguro.
6. Revisá el JSON: cada fuente debe aparecer sin error, `complete` debe ser `true`, y los conteos deben registrarse. Después verificá en SQL el total importado por fuente/categoría y que no haya duplicados de `source_key`.

## Películas y series

TMDB proporciona metadatos y carátulas, no URLs de reproducción. La función M3U no llena `movies`, `series` ni `episodes`. Para reproducir VOD, el propietario del catálogo debe agregar enlaces autorizados y verificables. No se deben inventar URLs ni presentar un registro solo de metadatos como contenido reproducible.
