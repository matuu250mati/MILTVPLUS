import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../adult/adult_gate_screen.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../live/live_tv_screen.dart';
import '../settings/settings_screen.dart';

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
    _NavItem('+18', Icons.lock_outline_rounded),
    _NavItem('CONFIGURACIÓN', Icons.settings_rounded),
  ];

  int selected = 1;

  Widget page() {
    switch (selected) {
      case 0:
        return const LiveTvScreen();
      case 1:
        return HomeScreen(onNavigate: (index) => setState(() => selected = index));
      case 2:
        return const CatalogScreen(category: 'PELÍCULAS');
      case 3:
        return const CatalogScreen(category: 'SERIES');
      case 4:
        return const CatalogScreen(category: 'ANIME');
      case 5:
        return const CatalogScreen(category: 'DEPORTES');
      case 6:
        return const CatalogScreen(category: 'INFANTIL');
      case 7:
        return const CatalogScreen(category: 'GRATIS');
      case 8:
        return const CatalogScreen(category: 'EXPLORAR');
      case 9:
        return const AdultGateScreen();
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
                  const Divider(height: 18, color: Color(0x303FFFFFFF)),
                  _drawerItem(9),
                  const Divider(height: 18, color: Color(0x303FFFFFFF)),
                  _drawerItem(10),
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
                              : item.label == '+18'
                                  ? 'Zona +18'
                                  : item.label == 'CONFIGURACIÓN'
                                      ? 'Perfil y configuración'
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
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
            onPressed: () => setState(() => selected = 10),
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
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: _pageView(),
            ),
          ),
        ],
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

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
