# MILTVPLUS — matriz de compatibilidad y publicación

Esta matriz distingue entre una compilación correcta y una reproducción validada en un dispositivo real. Ningún flujo de CI puede garantizar compatibilidad con todas las marcas, versiones del sistema, códecs o proveedores de streaming.

## Objetivos de plataforma

| Plataforma | Estado del proyecto | Qué falta para declarar compatibilidad |
| --- | --- | --- |
| Android móvil/tablet | Plataforma principal; APK y autenticación existentes | Pruebas en dispositivos reales, inicio/cierre de sesión, enlaces profundos y reproducción de las fuentes autorizadas |
| Android TV / Google TV | Manifiesto de TV y navegación D-pad existentes | Probar mando físico, foco visible, retorno, reproducción HLS y diferentes resoluciones |
| Fire TV / TV Box Android | Puede ejecutar el APK si la versión del sistema y sus servicios son compatibles | Validar por modelo; Fire OS y los códecs disponibles varían |
| Navegador web | Se agrega compilación Flutter Web de verificación | Configurar Supabase, CORS, URLs de retorno y alojamiento de la app; la página informativa no es por sí misma el reproductor web |
| Windows | Se habilita backend de vídeo de escritorio y compilación CI | Probar HLS/MP4, códecs, teclado, ratón, pantalla completa y empaquetado de distribución |
| Linux | Se habilita backend de vídeo de escritorio y compilación CI | Validar dependencias GTK, códecs instalados, HLS y empaquetado por distribución |
| macOS | Se comprueba compilación sin firma | Firma/notarización para distribución y prueba en Mac físico |
| iOS | Se comprueba compilación sin firma | Cuenta/certificado Apple, firma, enlaces de autenticación y prueba en iPhone/iPad |
| Samsung Tizen / LG webOS / Roku | No son destinos nativos de este APK Flutter | Requieren clientes específicos para cada sistema o un reproductor web compatible aprobado por la plataforma; no deben anunciarse como compatibles hasta tenerlos y probarlos |

## Comprobaciones automáticas

El flujo **Cross-platform build verification** intenta compilar Web, Windows, Linux, macOS e iOS en runners apropiados. Los binarios de esa ejecución son artefactos de QA, no una publicación estable ni una certificación de dispositivos. El APK Android se valida mediante el flujo Android existente.

Las compilaciones de verificación usan valores ficticios de Supabase y no deben distribuirse. La publicación real debe usar la URL del proyecto y la clave pública/anon correspondientes mediante configuración segura; nunca se debe incluir una clave `service_role` en una app cliente.

## Criterios mínimos antes de anunciar una plataforma como compatible

1. El build de esa plataforma termina correctamente.
2. La app arranca y la autenticación funciona con el proyecto Supabase real.
3. El catálogo carga datos publicados con políticas RLS correctas.
4. Se reproduce al menos una fuente HLS y una MP4 autorizadas; se comprueban CORS, HTTPS, redirecciones y códecs.
5. Se verifica navegación, foco, retroceso, orientación y recuperación tras perder la conexión.
6. Se prueba en un equipo físico representativo y se registra modelo, versión del sistema y resultado.
7. El paquete final está firmado cuando la plataforma lo requiere y tiene checksum de publicación.

## Límites importantes

- Un build correcto no demuestra que todas las URL de streaming funcionen. La disponibilidad, el DRM, los encabezados, CORS, el formato y los derechos dependen de cada proveedor.
- No se deben añadir listas o enlaces sin autorización ni prometer acceso a contenido de terceros.
- La compatibilidad con televisores Android no implica compatibilidad nativa con Tizen, webOS o Roku.
