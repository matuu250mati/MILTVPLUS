import 'dart:async';

import 'package:flutter/material.dart';
import 'core/navigation/legacy_route_registry.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';

class MiltvPlusApp extends StatelessWidget {
  const MiltvPlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MILTVPLUS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
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

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _introComplete = true);
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_introComplete) return const SplashScreen();
    // Explore the public parts of the app without forcing account creation.
    // Restricted sections enforce authentication at their own entry point.
    return const AppShell();
  }
}
