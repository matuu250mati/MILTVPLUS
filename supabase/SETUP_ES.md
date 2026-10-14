# Configuración de Supabase para MILTVPLUS

Esta guía cubre la configuración que el APK no puede aplicar por sí solo. Ejecutá estos pasos en el proyecto de Supabase que corresponde a los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` de GitHub Actions.

## 1. Crear las tablas base

Si el proyecto de Supabase está vacío, abrí **SQL Editor** y ejecutá el contenido completo de `supabase/schema.sql` desde este repositorio. Si las tablas ya existen y contienen datos, no vuelvas a ejecutar cambios destructivos: revisá primero el esquema existente.

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

1. Registrá una cuenta normal e iniciá sesión.
2. En **PUBLICAR**, enviá una película de prueba cuya URL HTTPS sea tuya o esté autorizada.
3. Confirmá en Supabase que la fila queda con `moderation_status = 'pending'`.
4. Iniciá sesión con la cuenta moderadora y abrí **MODERACIÓN**.
5. Aprobá la propuesta y verificá que aparezca en el catálogo público.
6. Abrí el título y confirmá reproducción real. Una URL que responda HTTP sin cifrar, una página web o una señal caída no cuenta como reproducción válida.

La compilación de GitHub Actions solo verifica el código y construye el APK; no confirma que esta configuración ya esté aplicada a la base de datos real.
