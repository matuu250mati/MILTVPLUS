# Configuración de Supabase para MILTVPLUS

Esta guía cubre la configuración que el APK no puede aplicar por sí solo. Ejecutá estos pasos en el proyecto de Supabase que corresponde a los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` de GitHub Actions.

## 1. Crear o compatibilizar las tablas

Si el proyecto de Supabase está vacío, abrí **SQL Editor** y ejecutá el contenido completo de `supabase/schema.sql`.

Si las tablas ya existen y contienen datos, no vuelvas a ejecutar cambios destructivos ni recrees `channels`. Inspeccioná primero sus columnas y hacé una copia de seguridad. La app necesita `channels.title`, `channels.url_stream`, `channels.is_published` y `channels.sort_order`.

Se agregó la migración no destructiva `supabase/migrations/20261014090000_channels_compatibility.sql`. Esta intenta mapear nombres heredados habituales (`name`/`channel_name` y `url`/`stream_url`, entre otros), conserva las filas y revierte toda la transacción si no puede asociar un nombre o URL válidos. Ejecutala en SQL Editor solo después de revisar las columnas existentes. Si falla, no fuerces la ejecución ni inventes datos: compartí el error SQL y la lista de nombres de columnas (sin valores privados) para preparar un mapeo exacto.

## Estado de la última comprobación automática

**Comprobación automática de CI (21/10/2026):** el flujo de QA consultó las columnas requeridas de `channels`, `movies`, `series`, `episodes` y `content_submissions`; las cinco devolvieron HTTP 200. Esta validación corresponde al proyecto QA seleccionado por el workflow, no certifica por sí sola el proyecto de producción.

El registro del 14/10/2026 había detectado nombres heredados en `channels` y un HTTP 404 para `content_submissions`. Esos hallazgos son históricos y no deben tomarse como el estado actual sin repetir la comprobación. Conservamos la migración de compatibilidad por si se configura otro proyecto o reaparece una diferencia de esquema.

La comprobación HTTP 200 confirma que PostgREST resolvió los nombres de columna usados en la consulta de diagnóstico. **No garantiza** que existan filas visibles para el rol anónimo, que las políticas RLS permitan cada operación de lectura/escritura ni que todos los flujos de cuenta y moderación funcionen. Antes de dar Supabase por cerrado, repetí la verificación en producción y probá autenticación, lectura como anon y authenticated, envíos de contenido y moderación.

## Despliegue automatizado de migraciones

El repositorio incluye `.github/workflows/deploy-supabase-migrations.yml`, que se ejecuta manualmente desde **GitHub → Actions → Deploy Supabase database migrations → Run workflow**. Antes de ejecutarlo, configurá en **Settings → Secrets and variables → Actions → Repository secrets** estos secretos del mismo proyecto:

- `SUPABASE_ACCESS_TOKEN`: token personal de acceso de Supabase.
- `SUPABASE_DB_PASSWORD`: contraseña de la base de datos del proyecto.
- `SUPABASE_URL`: URL raíz `https://<project-ref>.supabase.co`.
- `SUPABASE_ANON_KEY`: clave pública anon/publishable correspondiente al proyecto.

El workflow deriva automáticamente `SUPABASE_PROJECT_ID` de `SUPABASE_URL`, así que no hace falta guardar un secreto separado para ese dato. Que el APK compile no demuestra que `SUPABASE_ACCESS_TOKEN` y `SUPABASE_DB_PASSWORD` estén configurados para el entorno `production`. Confirmá que los cuatro secretos estén presentes en el entorno de GitHub Actions `production`; no los pegues en el chat. El workflow ahora rechaza explícitamente cualquier proyecto cuyo ref no sea el de producción esperado.

No pegues tokens, contraseñas ni claves en el chat ni en archivos versionados. El workflow valida que el ID y la URL coincidan, ejecuta `supabase db push`, revisa el historial y comprueba las columnas requeridas. Si falla por historial de migraciones o por esquema, no fuerces la ejecución: revisá el log y resolvé la causa antes de reintentar. El workflow no reemplaza una copia de seguridad ni una revisión de cambios sobre datos existentes.

## 2. Normalizar categorías de TV en vivo

Después de aplicar y verificar `20261014090000_channels_compatibility.sql`, revisá qué señales coinciden con los patrones de la migración `20261014150000_normalize_channel_categories.sql`. Esa migración clasifica nombres reconocibles como `Deportes` o `TV Argentina`, prioriza deportes cuando un canal cumple ambos patrones, conserva las URL y no cambia `is_published`. Las filas que no coinciden quedan intactas.

Vista previa orientativa antes de ejecutar la migración:

```sql
SELECT
  COALESCE(
    NULLIF(to_jsonb(c)->>'title', ''),
    NULLIF(to_jsonb(c)->>'name', ''),
    NULLIF(to_jsonb(c)->>'channel_name', ''),
    NULLIF(to_jsonb(c)->>'channel_title', '')
  ) AS channel_name,
  category,
  is_published
FROM public.channels AS c
WHERE lower(COALESCE(
    to_jsonb(c)->>'title',
    to_jsonb(c)->>'name',
    to_jsonb(c)->>'channel_name',
    to_jsonb(c)->>'channel_title',
    ''
  )) ~ '(espn|tyc[[:space:]]*sports|fox[[:space:]]*sports|tnt[[:space:]]*sports|dsports|deportv|telefe|eltrece|c5n|a24|canal[[:space:]]*26)'
  OR lower(COALESCE(to_jsonb(c)->>'country_code', '')) IN ('ar', 'argentina')
  OR lower(COALESCE(to_jsonb(c)->>'category', '')) IN ('argentina', 'tv en vivo', 'tv argentina')
ORDER BY category, channel_name;
```

Si la vista previa es correcta, ejecutá el archivo de migración completo desde SQL Editor de Supabase y verificá los conteos:

```sql
SELECT category, COUNT(*) AS cantidad
FROM public.channels
GROUP BY category
ORDER BY category;
```

No marques canales como publicados ni reemplaces URL durante esta clasificación. La app solo muestra filas con `is_published = true`.

## 3. Habilitar propuestas de la comunidad

En SQL Editor, ejecutá una sola vez el contenido actualizado de:

`supabase/migrations/20261013090200_user_content_submissions.sql`

Esta migración crea `content_submissions`, habilita RLS, permite a usuarios autenticados enviar propuestas pendientes y permite que usuarios autenticados lean únicamente las aprobadas. Los moderadores autorizados pueden revisar propuestas pendientes y cambiar `moderation_status`.

Si el SQL Editor devuelve un error, no continúes como si la migración hubiera quedado aplicada. Copiá el error completo (sin claves ni tokens) y corregilo antes de probar el flujo.

## 4. Asignar el rol de moderación

El rol se guarda en `app_metadata`, no en `user_metadata`, para que el usuario no pueda asignárselo desde la app. Después de crear la cuenta del moderador, un administrador del proyecto puede ejecutar lo siguiente en SQL Editor, reemplazando el correo por el de la cuenta autorizada:

```sql
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"moderator"}'::jsonb
where lower(email) = lower('moderador@tu-dominio.com');

select email, raw_app_meta_data ->> 'role' as role
from auth.users
where lower(email) = lower('moderador@tu-dominio.com');
```

Confirmá que la consulta de verificación devuelva exactamente una cuenta con el rol `moderator`. Cerrá sesión y volvé a iniciar sesión en MILTVPLUS para renovar el JWT y cargar el rol. No asignes este rol a cuentas que no deban aprobar publicaciones.

## 5. Política vigente de acceso al catálogo

El requisito vigente en esta rama es **catálogo solo para usuarios autenticados**. La migración correctiva `20261022100000_enforce_authenticated_catalog_access.sql` revoca la lectura del rol `anon` y permite a `authenticated` leer únicamente canales, películas y series publicados, episodios cuyo padre esté publicado y propuestas aprobadas. Reemplaza solo las políticas de lectura conocidas y restaura las políticas owner-only de películas, series y episodios, además de las políticas de moderación. Aun así, antes de aplicarla en producción, compará las políticas reales del proyecto con las migraciones y verificá los permisos de publicación de canales, porque el historial anterior pudo haber eliminado políticas personalizadas.

Las migraciones históricas `20261021210000_catalog_rls_hardening.sql` y `20261022090000_content_submissions_column_privileges.sql` contienen concesiones previas a `anon`; no las interpretes aisladamente. La migración correctiva posterior debe quedar registrada y aplicada en el proyecto destino. No ejecutes la migración de producción sin verificar primero el ID del proyecto, el historial de migraciones y las políticas personalizadas. No agregues políticas de escritura pública ni incluyas una clave `service_role` en la app.

## 6. Archivos de medios del propietario

La pantalla **PUBLICAR** sube archivos al bucket `owner-media` y guarda una URL pública para que el reproductor pueda abrirla. La migración `20261022110000_owner_media_storage_policies.sql` crea/configura ese bucket y limita las operaciones de escritura a sesiones autenticadas cuyo `app_metadata.role` sea `owner`.

**Importante:** el bucket es público para lectura por diseño: cualquier persona que obtenga la URL de un archivo puede intentar abrirlo, aunque el catálogo requiera iniciar sesión. Subí únicamente medios que tengas derecho a distribuir públicamente. Si el requisito es que el video también quede protegido detrás de autenticación, no alcanza con RLS del catálogo: habrá que cambiar el flujo para guardar la ruta del objeto y emitir URLs firmadas al reproducir; no se debe resolver haciendo privado el bucket sin adaptar antes el reproductor.

Tras aplicar la migración, probá con una cuenta normal que no pueda subir, reemplazar ni borrar objetos en `owner-media`, y con el rol `owner` que pueda subir y reproducir un archivo autorizado. La compilación de CI no ejecuta esta prueba contra producción.

## 7. Prueba de aceptación

1. Verificá que las tablas `channels`, `movies`, `series`, `episodes` y `content_submissions` existan y tengan las columnas consultadas por la app.
2. Confirmá en el historial de Supabase que la migración `20261022100000_enforce_authenticated_catalog_access.sql` se haya aplicado al proyecto correcto.
3. Con la clave pública y sin sesión, comprobá que las lecturas del catálogo no expongan filas (esperado: acceso denegado o cero filas según el endpoint y la política).
4. Registrá una cuenta normal e iniciá sesión; comprobá que puede leer únicamente el contenido publicado.
5. En **PUBLICAR**, enviá una propuesta de prueba cuya URL HTTPS sea tuya o esté autorizada.
6. Confirmá en Supabase que la fila queda con `moderation_status = 'pending'` y que un usuario no puede enviar propuestas asignándolas a otro `user_id` ni establecerlas como aprobadas.
7. Iniciá sesión con la cuenta moderadora y abrí **MODERACIÓN**; verificá que las acciones de moderación sigan funcionando con los permisos de servidor previstos.
8. Aprobá la propuesta y verificá que aparezca para un usuario autenticado autorizado.
9. Abrí el título y confirmá reproducción real. Una URL que responda HTTP sin cifrar, una página web o una señal caída no cuenta como reproducción válida.

La compilación de GitHub Actions solo verifica el código y construye el APK; no confirma que esta configuración ya esté aplicada a la base de datos real.
