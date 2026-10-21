# MILTVPLUS — matriz de compatibilidad y publicación

Esta matriz distingue entre una compilación correcta y una reproducción validada en un dispositivo real. Ningún flujo de CI puede garantizar compatibilidad con todas las marcas, versiones del sistema, códecs o proveedores de streaming.

## Objetivos de plataforma

| Plataforma | Estado del proyecto | Qué falta para declarar compatibilidad |
| --- | --- | --- |
| Android móvil/tablet | Plataforma principal; APK y autenticación existentes | Pruebas en dispositivos reales, inicio/cierre de sesión, enlaces profundos y reproducción de las fuentes autorizadas |
| Android TV / Google TV | Manifiesto de TV y navegación D-pad existentes | Probar mando físico, foco visible, retorno, reproducción HLS y diferentes resoluciones |
| Emuladores Android | El mismo APK Android es el artefacto de prueba; no requiere cliente separado | Probar versiones/API de Android, tamaños y densidades de pantalla, teclado/D-pad, aceleración de vídeo, códecs y reproducción; el resultado solo cubre las imágenes y configuraciones probadas |
| Fire TV / TV Box Android | Puede ejecutar el APK si la versión del sistema y sus servicios son compatibles | Validar por modelo; Fire OS y los códecs disponibles varían |
| Navegador web | Se agrega compilación Flutter Web de verificación | Configurar Supabase, CORS, URLs de retorno y alojamiento de la app; la página informativa no es por sí misma el reproductor web |
| Windows / macOS / Linux desktop | Fuera del alcance actual; no se compilan ni validan como objetivos de escritorio | Reabrir únicamente cuando el proyecto lo priorice expresamente; Linux desktop queda excluido según la decisión actual |
| macOS | Fuera de la matriz CI actual; no validado | Reincorporar cuando se necesite distribuir para Mac y haya un runner macOS operativo; luego firmar/notarizar y probar en equipo físico |
| iOS | Fuera de la matriz CI actual; no validado | Reincorporar cuando se necesite distribuir para iPhone/iPad y haya un runner macOS operativo; luego firmar y probar en equipo físico |
| Samsung Tizen / LG webOS / Roku | No son destinos nativos de este APK Flutter | Requieren clientes específicos para cada sistema o un reproductor web compatible aprobado por la plataforma; no deben anunciarse como compatibles hasta tenerlos y probarlos |

## Comprobaciones automáticas

La subida de artefactos usa `actions/upload-artifact@v6`, que ejecuta en Node.js 24 y evita la advertencia de runtime Node.js 20 de la versión anterior. La desaparición de avisos de dependencias se confirma en los registros de la siguiente ejecución; no se da por hecha antes de correr CI.

El flujo **Flutter CI** valida análisis y pruebas Dart/Flutter y compila Web como comprobación complementaria. Las compilaciones de escritorio para Windows, macOS y Linux quedan fuera del alcance actual; Linux desktop permanece excluido. `ubuntu-latest` se usa para análisis, pruebas y compilación Web, no como objetivo Linux. La prioridad de validación de producto es Android móvil/tablet, Android TV/Google TV y TV Box compatibles. El APK Android se valida mediante el flujo Android existente.

Las compilaciones de verificación usan valores ficticios de Supabase y no deben distribuirse. La publicación real debe usar la URL del proyecto y la clave pública/anon correspondientes mediante configuración segura; nunca se debe incluir una clave `service_role` en una app cliente.

## Criterios mínimos antes de anunciar una plataforma como compatible

1. El build de esa plataforma termina correctamente.
2. La app arranca y la autenticación funciona con el proyecto Supabase real.
3. En emuladores, registrar la imagen/API, resolución, configuración gráfica y dispositivo virtual; no generalizar el resultado a todos los emuladores.
4. El catálogo carga datos publicados con políticas RLS correctas.
5. Se reproduce al menos una fuente HLS y una MP4 autorizadas; se comprueban CORS, HTTPS, redirecciones y códecs.
6. Se verifica navegación, foco, retroceso, orientación y recuperación tras perder la conexión.
7. Se prueba en un equipo físico representativo y se registra modelo, versión del sistema y resultado.
8. El paquete final está firmado cuando la plataforma lo requiere y tiene checksum de publicación.

## Límites importantes

- Un build correcto no demuestra que todas las URL de streaming funcionen. La disponibilidad, el DRM, los encabezados, CORS, el formato y los derechos dependen de cada proveedor.
- No se deben añadir listas o enlaces sin autorización ni prometer acceso a contenido de terceros.
- La compatibilidad con televisores Android no implica compatibilidad nativa con Tizen, webOS o Roku.
