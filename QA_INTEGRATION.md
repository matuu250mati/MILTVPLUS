# MILTVPLUS — integración de QA

Esta rama (`qa/integration-pr27-pr31-2026-10-16`) combina los cambios de las PR #27, #28, #29, #30 y #31 únicamente para validación de integración.

## Contenido incluido
- #27: código de sincronización M3U y migración SQL preparada; **no desplegada ni ejecutada** contra Supabase.
- #28: modos de aspecto del reproductor en vivo.
- #29 y #30: ajustes de accesibilidad y navegación Android TV, splash y retroceso de onboarding.
- #31: persistencia y reanudación local del progreso VOD.

## Límites de seguridad
- No fusionar esta rama en `main` sin autorización explícita posterior.
- No ejecutar migraciones ni sincronizaciones sobre Supabase desde QA.
- No modificar la web oficial ni el código Downloader 1857055.
- El APK generado por los workflows de PR es un paquete QA (`com.miltvplus.miltv_plus.qa`), no un instalador de producción.
- CI exitoso no sustituye pruebas físicas en TCL/celulares ni valida que cada stream esté disponible.
