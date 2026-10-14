# Configuración de Supabase para MILTVPLUS

Esta guía cubre la configuración que el APK no puede aplicar por sí solo. Ejecutá estos pasos en el proyecto de Supabase que corresponde a los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` de GitHub Actions.

## 1. Crear o compatibilizar las tablas

Si el proyecto de Supabase está vacío, abrí **SQL Editor** y ejecutá el contenido completo de `supabase/schema.sql`.

Si las tablas ya existen y contienen datos, no vuelvas a ejecutar cambios destructivos ni recrees `channels`. Inspeccioná primero sus columnas y hacé una copia de seguridad. La app necesita `channels.title`, `channels.url_stream`, `channels.is_published` y `channels.sort_order`.

Se agregó la migración no destructiva `supabase/migrations/20261014_channels_compatibility.sql`. Esta intenta mapear nombres heredados habituales (`name`/`channel_name` y `url`/`stream_url`, entre otros), conserva las filas y revierte toda la transacción si no puede asociar un nombre o URL válidos. Ejecutala en SQL Editor solo después de revisar las columnas existentes. Si falla, no fuerces la ejecución ni inventes datos: compartí el error SQL y la lista de nombres de columnas (sin valores privados) para preparar un mapeo exacto.

## Hallazgos detectados por la verificación automática

La comprobación del proyecto Supabase configurado en GitHub detectó que las tablas `movies`, `series` y `episodes` responden, pero `content_submissions` no existe todavía en el esquema visible. También detectó que `channels` no tiene una columna `title` con el esquema esperado por MILTVPLUS. Por eso, no consideres la integración terminada hasta aplicar las migraciones y comprobar el esquema real.

## 2. Habilitar propuestas de la comunidad

En SQL Editor, ejecutá una sola vez el contenido actualizado de:

`supabase/migrations/20261013_user_content_submissions.sql`

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
