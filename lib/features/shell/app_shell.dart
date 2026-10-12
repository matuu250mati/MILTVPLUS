import 'package:flutter/material.dart';
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
    _NavItem('DESTACADOS', Icons.auto_awesome_rounded),
    _NavItem('PELÍCULAS', Icons.movie_creation_outlined),
    _NavItem('SERIES', Icons.video_library_outlined),
    _NavItem('ANIME', Icons.animation_rounded),
    _NavItem('EXPLORAR', Icons.explore_outlined),
    _NavItem('+18', Icons.lock_outline_rounded),
    _NavItem('PERFIL', Icons.manage_accounts_outlined),
  ];

  int selected = 0;
  bool? expanded;

  Widget page() {
    switch (selected) {
      case 0:
        return const LiveTvScreen();
      case 1:
        return const HomeScreen();
      case 2:
        return const CatalogScreen(category: 'PELÍCULAS');
      case 3:
        return const CatalogScreen(category: 'SERIES');
      case 4:
        return const CatalogScreen(category: 'ANIME');
      case 5:
        return const CatalogScreen(category: 'EXPLORAR');
      case 6:
        return const AdultGateScreen();
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final menuExpanded = expanded ?? wide;
    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: menuExpanded ? 224 : 72,
                  margin: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC111521),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 29),
                            ),
                            if (menuExpanded) ...[
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'MILTV\nPLUS',
                                  style: TextStyle(
                                    height: .98,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = selected == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Tooltip(
                                message: item.label,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(13),
                                  onTap: () => setState(() => selected = index),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: menuExpanded ? 12 : 0,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppTheme.accent.withValues(alpha: .13)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(13),
                                      border: active
                                          ? Border.all(color: AppTheme.accent.withValues(alpha: .35))
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: menuExpanded
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Icon(item.icon,
                                            size: 20,
                                            color: active ? AppTheme.accent : AppTheme.muted),
                                        if (menuExpanded) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                letterSpacing: .6,
                                                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                                color: active ? Colors.white : AppTheme.muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: menuExpanded ? 'Contraer menú' : 'Expandir menú',
                        onPressed: () => setState(() => expanded = !menuExpanded),
                        icon: Icon(menuExpanded
                            ? Icons.keyboard_double_arrow_left_rounded
                            : Icons.keyboard_double_arrow_right_rounded),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: KeyedSubtree(key: ValueKey(selected), child: page()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
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
