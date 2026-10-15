import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../adult/adult_gate_screen.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../live/live_tv_screen.dart';
import '../settings/settings_screen.dart';
import '../submissions/content_submission_screen.dart';
import '../submissions/content_moderation_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const items = <_NavItem>[
    _NavItem('TV EN VIVO', Icons.live_tv_rounded),
    _NavItem('INICIO', Icons.home_rounded),
    _NavItem('PELÍCULAS', Icons.movie_creation_outlined),
    _NavItem('SERIES', Icons.video_library_outlined),
    _NavItem('ANIME', Icons.animation_rounded),
    _NavItem('DEPORTES', Icons.sports_soccer_rounded),
    _NavItem('INFANTIL', Icons.child_care_rounded),
    _NavItem('GRATIS', Icons.card_giftcard_rounded),
    _NavItem('EXPLORAR', Icons.explore_outlined),
    _NavItem('PUBLICAR', Icons.publish_rounded),
    _NavItem('+18', Icons.lock_outline_rounded),
    _NavItem('CONFIGURACIÓN', Icons.settings_rounded),
    _NavItem('MODERACIÓN', Icons.fact_check_outlined),
  ];

  int selected = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeOnce());
  }

  Future<void> _showWelcomeOnce() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || (preferences.getBool('miltvplus_welcome_guide_seen_v1') ?? false)) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF111521),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFF5BE58B), size: 54)),
            const SizedBox(height: 10),
            const Center(child: Text('¡Bienvenido a MILTVPLUS! 🇦🇷', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            const SizedBox(height: 8),
            const Center(child: Text('Tu entretenimiento, ordenado y a tu manera.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted))),
            const SizedBox(height: 18),
            const _WelcomeStep(icon: Icons.live_tv_rounded, color: Color(0xFF58C7FF), title: 'TV en vivo', detail: 'Buscá por nombre, filtrá por país o categoría y tocá una señal para verla a pantalla completa.'),
            const _WelcomeStep(icon: Icons.sports_soccer_rounded, color: Color(0xFFFFB74D), title: 'Deportes', detail: 'Explorá señales deportivas. La disponibilidad depende de las fuentes públicas o autorizadas que estén activas.'),
            const _WelcomeStep(icon: Icons.lock_rounded, color: Color(0xFFB79CFF), title: 'Zona +18', detail: 'Requiere cuenta, confirmación de edad, aceptación de políticas y PIN. Guardá tu PIN en un lugar seguro.'),
            const _WelcomeStep(icon: Icons.settings_rounded, color: Color(0xFFFF7CA8), title: 'Configuración', detail: 'En la tuerquita podés cargar listas M3U, administrar tu perfil, consultar información y buscar actualizaciones.'),
            const SizedBox(height: 8),
            const Text('Para consultar información detallada, abrí Configuración y buscá “Información de MILTVPLUS”.', style: TextStyle(color: AppTheme.muted, height: 1.4, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('¡DALE, VAMOS!'),
            )),
          ]),
        ),
      ),
    );
    await preferences.setBool('miltvplus_welcome_guide_seen_v1', true);
  }

  bool get _isModerator {
    if (!isSupabaseConfigured) return false;
    final role = Supabase.instance.client.auth.currentUser?.appMetadata['role'];
    return role == 'admin' || role == 'moderator';
  }

  Widget page() {
    switch (selected) {
      case 0:
        return LiveTvScreen(onBack: () => setState(() => selected = 1));
      case 1:
        return HomeScreen(onNavigate: (index) => setState(() => selected = index));
      case 2:
        return const CatalogScreen(category: 'PELÍCULAS');
      case 3:
        return const CatalogScreen(category: 'SERIES');
      case 4:
        return const CatalogScreen(category: 'ANIME');
      case 5:
        return LiveTvScreen(categoryFilter: const ['Deportes'], onBack: () => setState(() => selected = 1));
      case 6:
        return const CatalogScreen(category: 'INFANTIL');
      case 7:
        return const CatalogScreen(category: 'GRATIS');
      case 8:
        return const CatalogScreen(category: 'EXPLORAR');
      case 9:
        return const ContentSubmissionScreen();
      case 10:
        return const AdultGateScreen();
      case 12:
        return const ContentModerationScreen();
      default:
        return const SettingsScreen();
    }
  }

  Widget _pageView() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(selected), child: page()),
      );

  Widget _buildDrawer() {
    final user = isSupabaseConfigured
        ? Supabase.instance.client.auth.currentUser
        : null;
    final email = user?.email;
    return Drawer(
      width: 304,
      backgroundColor: const Color(0xFF10131E),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF20243C), Color(0xFF10131E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 39,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'MILTVPLUS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email ?? 'Explorá el contenido sin iniciar sesión',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, height: 1.35),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                children: [
                  _drawerItem(1),
                  _drawerItem(0),
                  const Divider(height: 18, color: Color(0x30FFFFFF)),
                  _drawerItem(2),
                  _drawerItem(3),
                  _drawerItem(4),
                  _drawerItem(5),
                  _drawerItem(6),
                  _drawerItem(7),
                  _drawerItem(8),
                  _drawerItem(9),
                  const Divider(height: 18, color: Color(0x30FFFFFF)),
                  _drawerItem(10),
                  const Divider(height: 18, color: Color(0x30FFFFFF)),
                  _drawerItem(11),
                  if (_isModerator) ...[
                    const Divider(height: 18, color: Color(0x30FFFFFF)),
                    _drawerItem(12),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MILTVPLUS · Entretenimiento',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(int index) {
    final item = items[index];
    final active = selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        selected: active,
        selectedTileColor: AppTheme.accent.withValues(alpha: .13),
        leading: Icon(
          item.icon,
          color: active ? AppTheme.accent : AppTheme.muted,
        ),
        title: Text(
          item.label == 'TV EN VIVO'
              ? 'TV en Vivo'
              : item.label == 'PELÍCULAS'
                  ? 'Películas'
                  : item.label == 'SERIES'
                      ? 'Series'
                      : item.label == 'ANIME'
                          ? 'Anime'
                          : item.label == 'DEPORTES'
                  ? 'Deportes'
                  : item.label == 'INFANTIL'
                      ? 'Infantil / Kids'
                      : item.label == 'GRATIS'
                          ? 'Contenido gratis'
                          : item.label == 'EXPLORAR'
                              ? 'Explorar'
                              : item.label == 'PUBLICAR'
                              ? 'Proponer película o serie'
                              : item.label == '+18'
                                  ? 'Zona +18'
                                  : item.label == 'CONFIGURACIÓN'
                                      ? 'Perfil y configuración'
                                      : item.label == 'MODERACIÓN'
                                          ? 'Moderación de contenido'
                                          : 'Inicio',
          style: TextStyle(
            color: active ? Colors.white : AppTheme.muted,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          setState(() => selected = index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // Back from any section returns to the dashboard instead of closing the
      // application. Back on the dashboard retains Android's normal exit behavior.
      canPop: selected == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected != 1 && mounted) {
          setState(() => selected = 1);
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: selected == 10 ? null : AppBar(
        backgroundColor: const Color(0xFF080A10),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppTheme.accent),
        titleSpacing: 4,
        title: const Row(
          children: [
            Text(
              'MILTV',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            SizedBox(width: 5),
            Text(
              'PLUS',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: () => setState(() => selected = 11),
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            top: false,
            child: Padding(
              padding: selected == 10
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: _pageView(),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.85, -.9),
            radius: 1.5,
            colors: [Color(0xFF20243C), AppTheme.background, AppTheme.background],
            stops: [0, .38, 1],
          ),
        ),
        child: SizedBox.expand(),
      );
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.icon, required this.color, required this.title, required this.detail});
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .13),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .2), blurRadius: 10)],
        ),
        child: Icon(icon, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(detail, style: const TextStyle(color: AppTheme.muted, height: 1.4, fontSize: 12)),
      ])),
    ]),
  );
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
