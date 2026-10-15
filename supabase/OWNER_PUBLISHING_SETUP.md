# Activar el panel privado del propietario de MILTVPLUS

El panel **PUBLICAR** está disponible solo para un usuario cuyo JWT de Supabase tenga
`app_metadata.role = "owner"`. La autorización se valida en la app, en Row Level Security
(RLS) de Postgres y en las políticas de Storage. Ocultar el menú por sí solo no es seguridad.

## Configuración única en Supabase

1. Abrí el proyecto de Supabase correcto y entrá en **Authentication → Users**.
2. Abrí la cuenta que debe ser la única propietaria.
3. En **app_metadata** (metadatos administrados por el servidor), asigná:
   ```json
   { "role": "owner" }
   ```
   No coloques el rol en `user_metadata`: el usuario podría editar esos metadatos.
4. Confirmá que ninguna otra cuenta tenga `app_metadata.role = "owner"`.
5. Cerrá sesión en MILTVPLUS y volvé a iniciar sesión para renovar el JWT y cargar los metadatos nuevos.
6. Aplicá la migración `20261015100000_owner_only_publishing.sql` en el proyecto. Si los secretos de despliegue de Supabase están configurados en GitHub Actions, el workflow de producción la aplicará al integrarse a `main`. Revisá que el workflow termine en éxito antes de probar el panel.

## Cómo publicar

- **Película:** ingresá título, descripción, categoría, año, póster y seleccioná un video local o una URL HTTPS autorizada.
- **Serie:** publicá primero la ficha de la serie.
- **Episodio:** elegí una serie existente, indicá temporada y episodio, y seleccioná un archivo o URL HTTPS.
- Al guardar, la ficha se publica directamente y aparece a los usuarios que pueden leer el catálogo. El panel no ofrece borradores para evitar que un archivo del bucket público quede accesible antes de publicar su ficha.
- Los archivos seleccionados se guardan en el bucket `owner-media`. Los videos grandes dependen del límite de almacenamiento y de transferencia configurado en el plan de Supabase.

## Límites reales

La app acepta archivos de video compatibles y URLs HTTPS autorizadas. Subir un archivo MP4 no lo convierte automáticamente en HLS ni genera varias calidades adaptativas. Para reproducción adaptativa tipo Netflix se necesita una canalización de transcodificación y empaquetado HLS/DASH, además de almacenamiento y CDN adecuados.

Nunca agregues una clave `service_role` al APK ni la compartas por chat. La app usa la clave pública de Supabase; los permisos sensibles se hacen cumplir en el servidor.
