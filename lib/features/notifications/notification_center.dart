import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../services/catalog_service.dart';
import '../../services/ota_update_service.dart';

class NotificationCenter {
  NotificationCenter._();

  static Future<void> show(BuildContext context) async {
    final catalog = CatalogService();
    final preferences = await SharedPreferences.getInstance();

    List<int> counts;
    try {
      counts = await Future.wait<int>([
        catalog.getChannels().then((items) => items.length),
        catalog.getMovies().then((items) => items.length),
        catalog.getSeries().then((items) => items.length),
      ]);
    } catch (_) {
      counts = const [-1, -1, -1];
    }

    final oldCounts = [
      preferences.getInt('miltv_notifications_channels_v1'),
      preferences.getInt('miltv_notifications_movies_v1'),
      preferences.getInt('miltv_notifications_series_v1'),
    ];
    final catalogAvailable = counts.every((count) => count >= 0);
    final hasGrowth = catalogAvailable && List<int>.generate(3, (i) => i)
        .any((i) => oldCounts[i] != null && counts[i] > oldCounts[i]!);
    final firstCheck = oldCounts.every((count) => count == null);

    if (catalogAvailable) {
      await preferences.setInt('miltv_notifications_channels_v1', counts[0]);
      await preferences.setInt('miltv_notifications_movies_v1', counts[1]);
      await preferences.setInt('miltv_notifications_series_v1', counts[2]);
    }

    String updateMessage = 'No se pudo comprobar ahora si hay una versión nueva.';
    bool updateAvailable = false;
    try {
      final info = await OtaUpdateService().checkForUpdate();
      updateAvailable = info.updateAvailable;
      updateMessage = updateAvailable
          ? 'Hay una versión nueva disponible: ${info.latestVersion}.'
          : info.message;
    } catch (_) {
      // Keep the failure explicit; never report an update check as successful.
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101725),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: AppTheme.accent),
            SizedBox(width: 10),
            Expanded(child: Text('Novedades de MILTVPLUS')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _NoticeRow(
                  icon: hasGrowth ? Icons.new_releases_rounded : Icons.live_tv_rounded,
                  title: hasGrowth
                      ? 'El catálogo creció desde la última revisión'
                      : firstCheck
                          ? 'Primera revisión del catálogo'
                          : 'Estado del catálogo',
                  detail: catalogAvailable
                      ? 'Canales: ${counts[0]} · Películas: ${counts[1]} · Series: ${counts[2]}.'
                      : 'No se pudo consultar el catálogo. Revisá la conexión y la configuración del servicio.',
                  highlighted: hasGrowth,
                ),
                const SizedBox(height: 14),
                _NoticeRow(
                  icon: updateAvailable ? Icons.system_update_alt_rounded : Icons.info_outline_rounded,
                  title: 'Actualizaciones de la aplicación',
                  detail: updateMessage,
                  highlighted: updateAvailable,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Este centro revisa novedades al abrirlo. Las notificaciones push automáticas requieren configurar un servicio de avisos en el servidor; no se simulan avisos en segundo plano.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.highlighted,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlighted ? AppTheme.accent : AppTheme.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(detail, style: const TextStyle(color: AppTheme.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      );
}
