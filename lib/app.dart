import 'dart:async';

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';

class MiltvPlusApp extends StatefulWidget {
  const MiltvPlusApp({super.key});

  @override
  State<MiltvPlusApp> createState() => _MiltvPlusAppState();
}

class _MiltvPlusAppState extends State<MiltvPlusApp> {
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 2300), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, animation, secondaryAnimation) => const AppShell(),
            transitionsBuilder: (_, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 420),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MILTV PLUS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      );
}
