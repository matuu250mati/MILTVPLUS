import 'dart:async';

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';

class MiltvPlusApp extends StatelessWidget {
  const MiltvPlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MILTV PLUS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
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

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, secondaryAnimation) => const AppShell(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 420),
        ),
      );
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
