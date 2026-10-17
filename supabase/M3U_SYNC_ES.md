# Sincronización de listas M3U para MILTVPLUS

## Qué importa y qué no

El sincronizador guarda entradas únicamente en `public.channels`. Las listas de IPTV-org para `movies.m3u` y `series.m3u` son categorías de canales lineales; no son un inventario de películas completas ni de temporadas/episodios VOD. Por eso sus entradas se clasifican como canales temáticos y **no** se insertan en `movies` ni `series`.

Solo se importan entradas con una URL HTTPS directa cuyo path termina en `.m3u8`. Se excluyen URLs HTTP, páginas web, YouTube/Twitch y enlaces que no son manifiestos HLS directos. Esto mejora la compatibilidad, pero no garantiza que cada señal siga activa ni certifica derechos de redistribución.

## Pasos de despliegue

1. Revisá que los secretos de GitHub para desplegar migraciones estén configurados en el proyecto correcto: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_URL` y `SUPABASE_ANON_KEY`. La migración nueva agrega columnas nullable y una clave única para registros administrados por el sincronizador; no elimina ni reemplaza registros existentes.
2. Aplicá `supabase/migrations/20261016110000_m3u_catalog_sync.sql` con el workflow **Deploy Supabase database migrations** o desde un entorno local enlazado al proyecto correcto. Revisá el resultado antes de continuar.
3. Configurá el secreto de Edge Function `SYNC_SECRET` en Supabase. Usá un valor aleatorio fuerte; no lo pegues en el repositorio ni en el chat. La función usa `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` del entorno del servidor.
4. Desplegá la función desde un entorno seguro con Supabase CLI:

   ```bash
   supabase functions deploy sync-m3u-catalog --no-verify-jwt
   ```

   `--no-verify-jwt` permite invocarla con el secreto de sincronización propio. La función rechaza solicitudes sin el encabezado `x-sync-secret` válido.
5. Ejecutá la sincronización desde una terminal segura, sin imprimir ni compartir el secreto:

   ```bash
   curl --fail-with-body --silent --show-error \
     -X POST "$SUPABASE_URL/functions/v1/sync-m3u-catalog" \
     -H "x-sync-secret: $SYNC_SECRET" \
     -H "Content-Type: application/json" \
     -d '{}'
   ```

   `SUPABASE_URL` y `SYNC_SECRET` deben estar definidos en el entorno local. No subas un archivo `.env` con esos valores.
6. Revisá el JSON de respuesta. Incluye el conteo por fuente (`fetched`, `accepted`, `rejected`, `duplicates`) y errores. La función procesa lotes de 100 y no tiene un límite fijo de 5.000 filas. `complete` solo será `true` si las 14 fuentes se descargaron sin errores, cada fuente produjo al menos una entrada elegible y todas las filas preparadas fueron confirmadas por la respuesta de escritura de Supabase. Si alguna fuente falla o no contiene URLs HLS elegibles, el resultado será incompleto; corregí la fuente y repetí la ejecución.

## Verificación de separación y duplicados

Ejecutá en Supabase SQL Editor:

```sql
select category, source_name, count(*) as channels
from public.channels
where source_key is not null
group by category, source_name
order by category, source_name;

select count(*) as managed_channels
from public.channels
where source_key is not null;

select source_key, count(*) as duplicates
from public.channels
where source_key is not null
group by source_key
having count(*) > 1;
```

La última consulta debe devolver cero filas. Las filas importadas se mantienen en `channels`; esta función no escribe en `movies`, `series` ni `episodes`, no elimina canales antiguos y no reemplaza registros manuales sin `source_key`. Si una señal deja de aparecer en una lista, el registro anterior queda conservado para evitar borrar datos sin revisión.

## Límites importantes

- La importación verifica las escrituras por lote y reporta entradas rechazadas/duplicadas, pero no prueba cada stream individual ni promete disponibilidad permanente.
- Los proveedores de las listas pueden cambiar, limitar o retirar URLs.
- El contenido se publica en la app al importarse con `is_published = true`; revisá las fuentes y sus permisos antes de distribuir una versión pública.
- La sincronización requiere que la migración esté aplicada y la Edge Function desplegada en el mismo proyecto Supabase al que apunta MILTVPLUS. Un commit o un APK exitoso no ejecuta por sí mismo la importación.
