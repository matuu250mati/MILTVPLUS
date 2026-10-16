import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/accessibility_settings.dart';
import 'core/navigation/legacy_route_registry.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/update_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/tv_onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MiltvPlusApp extends StatelessWidget {
  const MiltvPlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MILTVPLUS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => Shortcuts(
          // Android TV remotes commonly expose their D-pad as arrow keys and
          // the center/OK button as Enter or Select. Keep these mappings global
          // so standard Flutter controls work consistently across screens.
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowUp):
                DirectionalFocusIntent(TraversalDirection.up),
            SingleActivator(LogicalKeyboardKey.arrowDown):
                DirectionalFocusIntent(TraversalDirection.down),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                DirectionalFocusIntent(TraversalDirection.left),
            SingleActivator(LogicalKeyboardKey.arrowRight):
                DirectionalFocusIntent(TraversalDirection.right),
            SingleActivator(LogicalKeyboardKey.enter):
                ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter):
                ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.select):
                ActivateIntent(),
          },
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ValueListenableBuilder<double>(
              valueListenable: AppAccessibilitySettings.textScale,
              builder: (context, scale, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        routes: LegacyRouteRegistry.routes,
        home: const _IntroCoordinator(),
      );
}

class _IntroCoordinator extends StatefulWidget {
  const _IntroCoordinator();

  @override
  State<_IntroCoordinator> createState() => _IntroCoordinatorState();
}

class _IntroCoordinatorState extends State<_IntroCoordinator> {
  Timer? _introTimer;
  bool _introComplete = false;
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _introComplete = true);
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_updateCheckStarted) return;
    _updateCheckStarted = true;
    final update = await UpdateService.checkForUpdate();
    if (!mounted || update == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (dialogContext) => PopScope(
        canPop: !update.forceUpdate,
        child: AlertDialog(
          title: Text(update.forceUpdate
              ? 'Actualización obligatoria'
              : 'Nueva versión disponible'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versión instalada: ${update.currentVersion}'),
                Text('Nueva versión: ${update.latestVersion}'),
                if (update.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(update.releaseNotes),
                ],
                if (update.forceUpdate) ...[
                  const SizedBox(height: 12),
                  const Text('Necesitás actualizar para continuar usando MILTVPLUS.'),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Android solicitará confirmación para instalar el APK. No hace falta desinstalar primero.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            if (!update.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Más tarde'),
              ),
            TextButton(
              onPressed: () async {
                try {
                  await UpdateService.downloadAndOpenInstaller(update.downloadUrl);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo iniciar la actualización: $error')),
                  );
                }
              },
              child: const Text('Descargar e instalar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_introComplete) return const SplashScreen();

    if (!isSupabaseConfigured) return const AuthScreen();

    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        // The current session is authoritative on initial render and after
        // sign-in/sign-out events; RLS independently protects database rows.
        if (auth.currentSession == null) {
          return const AuthScreen();
        }
        return const _AuthenticatedGate();
      },
    );
  }
}


class _AuthenticatedGate extends StatefulWidget {
  const _AuthenticatedGate();

  @override
  State<_AuthenticatedGate> createState() => _AuthenticatedGateState();
}

class _AuthenticatedGateState extends State<_AuthenticatedGate> {
  bool? _termsAccepted;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _termsAccepted = preferences.getBool('miltv_terms_accepted_v1') ?? false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _termsAccepted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_termsAccepted == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }
    if (!_termsAccepted!) return const TvOnboardingScreen();
    return const AppShell();
  }
}
