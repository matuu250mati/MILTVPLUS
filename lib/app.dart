import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/accessibility_settings.dart';
import 'core/navigation/legacy_route_registry.dart';
import 'core/theme/app_theme.dart';
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
  // Keep the branded intro brief; a long fixed timer makes the app appear
  // frozen on TV boxes and phones even when the app is ready.
  static const _introDuration = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    // Restore the saved, bounded text scale before the main screens are shown.
    unawaited(AppAccessibilitySettings.load().catchError((_) {}));
    _introTimer = Timer(_introDuration, _finishIntro);
  }

  void _finishIntro() {
    _introTimer?.cancel();
    if (!mounted || _introComplete) return;
    setState(() => _introComplete = true);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_introComplete) return SplashScreen(onSkip: _finishIntro);

    // The main catalog is available in guest mode. Authentication is requested
    // only for account features (from Settings) and the restricted +18 area.
    // Keep the terms/onboarding gate, but do not make a session a launch prerequisite.
    return const _AuthenticatedGate();
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
