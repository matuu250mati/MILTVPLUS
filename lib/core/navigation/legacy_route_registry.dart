import 'package:flutter/material.dart';

import '../../features/catalog/catalog_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';

/// Compatibility registry for the legacy Android module paths.
/// These are Flutter route names, not network endpoints.
abstract final class LegacyRouteRegistry {
  static const metadata = <String, Map<String, Object>>{
    'http://module_vod/VodDetailsActivity': {
      'className': 'com.vod.ui.activity.VodDetailsActivity',
      'description': 'Detalles de una película o serie',
    },
    'http://module_vod/VodCategoryActivity': {
      'className': 'com.vod.ui.activity.VodCategoryActivity',
      'description': 'Categorías del catálogo',
    },
    'http://module_vod/UserCenterActivity': {
      'className': 'com.vod.ui.activity.UserCenterActivity',
      'description': 'Centro de usuario',
    },
    'http://module_vod/TopicActivity': {
      'className': 'com.vod.ui.activity.TopicActivity',
      'description': 'Colecciones y temas',
    },
    'http://module_mine/UserCenterActivity': {
      'className': 'com.mine.ui.activity.UserCenterActivity',
      'description': 'Perfil y configuración de usuario',
    },
    'http://module_mine/InviteFriendsActivity': {
      'className': 'com.mine.ui.activity.InviteFriendsActivity',
      'description': 'Invitaciones de usuarios',
    },
    'http://module_main/HomeActivity': {
      'className': 'com.main.ui.activity.HomeActivity',
      'description': 'Pantalla principal',
    },
    'http://module_login/ForcePasswordChangeActivity': {
      'className': 'com.login.ui.activity.ForcePasswordChangeActivity',
      'description': 'Cambio obligatorio de contraseña; requiere autenticación real',
    },
    'http://download/DownloadActivity': {
      'className': 'com.download.activity.DownloadActivity',
      'description': 'Gestor de descargas',
    },
  };

  static Map<String, WidgetBuilder> get routes => {
        'http://module_vod/VodDetailsActivity': (_) =>
            const LegacyFeaturePlaceholderScreen(
              title: 'DETALLES DEL CONTENIDO',
              message:
                  'La ruta está registrada. La ficha necesita recibir un identificador de película o serie para cargar sus datos.',
              icon: Icons.movie_outlined,
            ),
        'http://module_vod/VodCategoryActivity': (_) =>
            const CatalogScreen(category: 'EXPLORAR'),
        'http://module_vod/UserCenterActivity': (_) => const SettingsScreen(),
        'http://module_vod/TopicActivity': (_) =>
            const LegacyFeaturePlaceholderScreen(
              title: 'COLECCIONES Y TEMAS',
              message:
                  'La navegación está registrada. Esta pantalla necesita datos de colecciones desde el catálogo.',
              icon: Icons.collections_bookmark_outlined,
            ),
        'http://module_mine/UserCenterActivity': (_) => const SettingsScreen(),
        'http://module_mine/InviteFriendsActivity': (_) =>
            const LegacyFeaturePlaceholderScreen(
              title: 'INVITAR AMIGOS',
              message:
                  'La función requiere un sistema de invitaciones y enlaces emitidos por el backend.',
              icon: Icons.group_add_outlined,
            ),
        'http://module_main/HomeActivity': (_) => const AppShell(),
        'http://module_login/ForcePasswordChangeActivity': (_) =>
            const LegacyFeaturePlaceholderScreen(
              title: 'CAMBIO DE CONTRASEÑA',
              message:
                  'El cambio obligatorio debe activarse desde una sesión autenticada y una señal verificada del backend. No se fuerza desde una ruta pública.',
              icon: Icons.lock_reset_outlined,
            ),
        'http://download/DownloadActivity': (_) =>
            const LegacyFeaturePlaceholderScreen(
              title: 'DESCARGAS',
              message:
                  'El acceso está registrado, pero el gestor de descargas todavía necesita una implementación de almacenamiento y permisos.',
              icon: Icons.download_outlined,
            ),
      };
}

class LegacyFeaturePlaceholderScreen extends StatelessWidget {
  const LegacyFeaturePlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('MILTV PLUS')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('VOLVER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
