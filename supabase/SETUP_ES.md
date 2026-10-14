# Configuración de Supabase para MILTVPLUS

Esta guía cubre la configuración que el APK no puede aplicar por sí solo. Ejecutá estos pasos en el proyecto de Supabase que corresponde a los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` de GitHub Actions.

## 1. Crear o compatibilizar las tablas

Si el proyecto de Supabase está vacío, abrí **SQL Editor** y ejecutá el contenido completo de `supabase/schema.sql`.

Si las tablas ya existen y contienen datos, no vuelvas a ejecutar cambios destructivos ni recrees `channels`. Inspeccioná primero sus columnas y hacé una copia de seguridad. La app necesita `channels.title`, `channels.url_stream`, `channels.is_published` y `channels.sort_order`.

Se agregó la migración no destructiva `supabase/migrations/20261014090000_channels_compatibility.sql`. Esta intenta mapear nombres heredados habituales (`name`/`channel_name` y `url`/`stream_url`, entre otros), conserva las filas y revierte toda la transacción si no puede asociar un nombre o URL válidos. Ejecutala en SQL Editor solo después de revisar las columnas existentes. Si falla, no fuerces la ejecución ni inventes datos: compartí el error SQL y la lista de nombres de columnas (sin valores privados) para preparar un mapeo exacto.

## Hallazgos detectados por la verificación automática

La última comprobación automática del proyecto Supabase configurado en GitHub (14/10/2026) encontró estos datos concretos:

- `channels` responde, pero su esquema visible usa `name`, `stream_url` y `logo_url` en vez de `title`, `url_stream` y `logo`. También expone `category`, `created_at`, `id`, `is_published` y `sort_order`.
- `movies`, `series` y `episodes` existen y sus endpoints responden, aunque la consulta anónima no encontró filas visibles en ese momento.
- `content_submissions` devuelve HTTP 404: todavía no aparece en el esquema visible de PostgREST.

La migración de compatibilidad mapea `name → title`, `stream_url → url_stream` y `logo_url → logo` sin borrar las columnas ni las filas antiguas. No consideres la integración terminada hasta ejecutar la migración en el proyecto correcto y repetir la comprobación.

## Despliegue automatizado de migraciones

El repositorio incluye `.github/workflows/deploy-supabase-migrations.yml`, que se ejecuta manualmente desde **GitHub → Actions → Deploy Supabase database migrations → Run workflow**. Antes de ejecutarlo, configurá en **Settings → Secrets and variables → Actions → Repository secrets** estos secretos del mismo proyecto:

- `SUPABASE_ACCESS_TOKEN`: token personal de acceso de Supabase.
- `SUPABASE_DB_PASSWORD`: contraseña de la base de datos del proyecto.
- `SUPABASE_URL`: URL raíz `https://<project-ref>.supabase.co`.
- `SUPABASE_ANON_KEY`: clave pública anon/publishable correspondiente al proyecto.

El workflow deriva automáticamente `SUPABASE_PROJECT_ID` de `SUPABASE_URL`, así que no hace falta guardar un secreto separado para ese dato. En este repositorio ya se validó que `SUPABASE_URL` y `SUPABASE_ANON_KEY` están disponibles para compilar; lo que falta para desplegar es configurar `SUPABASE_ACCESS_TOKEN` y `SUPABASE_DB_PASSWORD`.

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

Esta migración crea `content_submissions`, habilita RLS, permite a usuarios autenticados enviar propuestas pendientes y permite que el público lea únicamente las aprobadas. Los moderadores solo pueden cambiar el campo `moderation_status`.

Si el SQL Editor devuelve un error, no continúes como si la migración hubiera quedado aplicada. Copiá el error completo (sin claves ni tokens) y corregilo antes de probar el flujo.

## 3. Asignar el rol de moderación

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

## 4. Verificar las políticas del catálogo

Las tablas `channels`, `movies`, `series` y `episodes` deben tener RLS habilitado y políticas de lectura para filas publicadas. El esquema base `supabase/schema.sql` incluye esas políticas. No agregues políticas de escritura pública ni incluyas una clave `service_role` en la app.

## 5. Prueba de aceptación

1. Verificá que las tablas `channels`, `movies`, `series` y `episodes` existan y tengan las columnas consultadas por la app.
2. Confirmá que `content_submissions` exista después de aplicar su migración.
3. Registrá una cuenta normal e iniciá sesión.
4. En **PUBLICAR**, enviá una película de prueba cuya URL HTTPS sea tuya o esté autorizada.
5. Confirmá en Supabase que la fila queda con `moderation_status = 'pending'`.
6. Iniciá sesión con la cuenta moderadora y abrí **MODERACIÓN**.
7. Aprobá la propuesta y verificá que aparezca en el catálogo público.
8. Abrí el título y confirmá reproducción real. Una URL que responda HTTP sin cifrar, una página web o una señal caída no cuenta como reproducción válida.

La compilación de GitHub Actions solo verifica el código y construye el APK; no confirma que esta configuración ya esté aplicada a la base de datos real.
