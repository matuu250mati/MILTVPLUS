import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../adult/adult_gate_screen.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/owner_publishing_screen.dart';
import '../home/home_screen.dart';
import '../live/live_tv_screen.dart';
import '../settings/settings_screen.dart';
import '../onboarding/miltvplus_guide.dart';
import '../submissions/content_moderation_screen.dart';
import '../../services/ota_update_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
  Timer? _updateTimer;
  DateTime? _lastUpdateCheck;
  bool _updateDialogShowing = false;
  DateTime? _lastBackPressAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showWelcomeOnce();
      if (mounted) await _checkForUpdate();
    });
    _updateTimer = Timer.periodic(const Duration(hours: 6), (_) {
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final lastCheck = _lastUpdateCheck;
      if (lastCheck == null ||
          DateTime.now().difference(lastCheck) > const Duration(minutes: 30)) {
        _checkForUpdate();
      }
    }
  }

  Future<void> _checkForUpdate() async {
    if (_updateDialogShowing || !mounted) return;
    _lastUpdateCheck = DateTime.now();
    final service = OtaUpdateService();
    final info = await service.checkForUpdate();
    if (!mounted) return;
    if (!info.updateAvailable) {
      // Surface OTA failures instead of silently treating them as "up to date".
      if (info.message != 'MILTVPLUS está actualizado.') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(info.message),
            duration: const Duration(seconds: 7),
          ),
        );
      }
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final snoozedUntil = preferences.getInt('miltvplus_update_snooze_until_ms_v1') ?? 0;
    if (!info.mandatory && DateTime.now().millisecondsSinceEpoch < snoozedUntil) return;
    if (!mounted || _updateDialogShowing) return;

    _updateDialogShowing = true;
    bool installNow = false;
    try {
      installNow = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF111521),
              title: Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: Color(0xFF00FF66)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(info.mandatory
                        ? 'Actualización de seguridad obligatoria'
                        : 'Nueva versión de MILTVPLUS'),
                  ),
                ],
              ),
              content: Text(
                'Versión instalada: ${info.currentVersion}\n'
                'Nueva versión: ${info.latestVersion}\n'
                'Tamaño aproximado: ${info.formattedSize}\n\n'
                '${info.mandatory ? 'Esta versión se marcó como necesaria para continuar usando MILTVPLUS.' : 'Podés actualizar ahora o recordarlo más tarde.'}',
                style: const TextStyle(height: 1.5),
              ),
              actions: [
                if (!info.mandatory)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('RECORDARME DESPUÉS'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(info.mandatory ? 'ACTUALIZAR PARA CONTINUAR' : 'ACTUALIZAR AHORA'),
                ),
              ],
            ),
          ) ??
          false;
      if (!installNow && !info.mandatory) {
        await preferences.setInt(
          'miltvplus_update_snooze_until_ms_v1',
          DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch,
        );
      }
    } finally {
      _updateDialogShowing = false;
    }

    if (installNow && mounted) {
      final result = await service.checkAndInstall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), duration: const Duration(seconds: 6)),
        );
      }
    }
  }

  Future<void> _showWelcomeOnce() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted ||
        (preferences.getBool('miltvplus_welcome_guide_seen_v2') ?? false)) {
      return;
    }

    final profileName =
        preferences.getString('miltv_profile_name_v1') ?? 'Usuario MILTVPLUS';
    await showMiltvPlusGuide(context, profileName: profileName);
    await preferences.setBool('miltvplus_welcome_guide_seen_v2', true);
  }

  bool get _isOwner {
    if (!isSupabaseConfigured) return false;
    return Supabase.instance.client.auth.currentUser?.appMetadata['role'] == 'owner';
  }

  bool get _isModerator {
    if (!isSupabaseConfigured) return false;
    final role = Supabase.instance.client.auth.currentUser?.appMetadata['role'];
    return role == 'admin' || role == 'owner';
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
        return const OwnerPublishingScreen();
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
                  colors: [Color(0xFF0A0F1D), Color(0xFF030712)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FF66), Color(0xFF00E5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: .20),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 43,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF07111F),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppTheme.accent, width: 2.2),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
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
                  if (_isOwner) _drawerItem(9),
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
    final label = switch (item.label) {
      'TV EN VIVO' => 'TV en Vivo',
      'PELÍCULAS' => 'Películas',
      'SERIES' => 'Series',
      'ANIME' => 'Anime',
      'DEPORTES' => 'Deportes',
      'INFANTIL' => 'Infantil / Kids',
      'GRATIS' => 'Catálogo global',
      'EXPLORAR' => 'Explorar',
      'PUBLICAR' => 'Publicación de contenido',
      '+18' => 'Zona +18',
      'CONFIGURACIÓN' => 'Configuración',
      'MODERACIÓN' => 'Moderación de contenido',
      _ => 'Inicio',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00FF66)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: active
              ? [BoxShadow(color: AppTheme.accent.withValues(alpha: .13), blurRadius: 14)]
              : const [],
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          selected: active,
          selectedTileColor: Colors.transparent,
          leading: Icon(item.icon, color: active ? const Color(0xFF031018) : AppTheme.muted),
          title: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF031018) : AppTheme.muted,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          onTap: () {
            Navigator.of(context).pop();
            setState(() => selected = index);
          },
        ),
      ),
    );
  }

  Widget _buildStatusFooter() {
    final user = isSupabaseConfigured ? Supabase.instance.client.auth.currentUser : null;
    final profile = user?.email?.trim();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF050A14),
        border: Border(top: BorderSide(color: Color(0xFF15324A))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final textSize = compact ? 9.0 : 11.0;
            return Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: AppTheme.accent, size: 7),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'MILTVPLUS v3.10.8',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.muted, fontSize: textSize, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    compact ? (profile == null || profile.isEmpty ? 'Usuario: Invitado' : profile) : 'Usuario: ${profile == null || profile.isEmpty ? 'Invitado' : profile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: textSize),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.wifi_rounded, color: AppTheme.accent, size: compact ? 12 : 15),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          compact ? 'ARG' : 'Conectado · ARG 🇦🇷',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.accent, fontSize: textSize, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWideSidebar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0F1D), Color(0xFF030712)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FF66), Color(0xFF00E5FF)],
                      ),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF07101B), size: 30),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                          children: [
                            TextSpan(text: 'MILTV'),
                            TextSpan(text: 'PLUS', style: TextStyle(color: AppTheme.accent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                children: [
                  _drawerItem(1),
                  _drawerItem(0),
                  _drawerItem(5),
                  const Divider(height: 20, color: Color(0x303A91C5)),
                  _drawerItem(2),
                  _drawerItem(3),
                  _drawerItem(4),
                  _drawerItem(6),
                  _drawerItem(7),
                  _drawerItem(8),
                  if (_isModerator) _drawerItem(9),
                  const Divider(height: 20, color: Color(0x303A91C5)),
                  _drawerItem(10),
                  _drawerItem(11),
                  if (_isModerator) _drawerItem(12),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 9, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('MILTVPLUS · Streaming', style: TextStyle(color: AppTheme.muted, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // A first Back returns to the dashboard. On the dashboard, require a
      // second Back within two seconds before leaving the app accidentally.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !mounted) return;
        if (selected != 1) {
          _lastBackPressAt = null;
          setState(() => selected = 1);
          return;
        }

        final now = DateTime.now();
        final lastPress = _lastBackPressAt;
        if (lastPress != null &&
            now.difference(lastPress) <= const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }

        _lastBackPressAt = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Presioná Atrás otra vez para salir de MILTVPLUS.'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Scaffold(
      backgroundColor: AppTheme.background,
      // Inicio already renders its own header inside the scrollable dashboard.
      appBar: selected == 1 ? null : ((selected == 10 || selected == 0 || selected == 5) ? AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppTheme.accent),
        titleSpacing: 4,
        title: const SizedBox.shrink(),
      ) : AppBar(
        backgroundColor: const AppTheme.background,
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
      )),
      drawer: _buildDrawer(),
      bottomNavigationBar: _buildStatusFooter(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 1000;
          if (wideLayout) {
            return Row(
              children: [
                SizedBox(width: 218, child: _buildWideSidebar()),
                const VerticalDivider(width: 1, color: Color(0xFF17304A)),
                Expanded(
                  child: Stack(
                    children: [
                      const _AmbientBackground(),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: selected == 10
                              ? EdgeInsets.zero
                              : const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: _pageView(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Stack(
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
          );
        },
      ),
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

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
