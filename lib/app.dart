import 'dart:async';

import 'package:flutter/material.dart';
import 'core/navigation/legacy_route_registry.dart';
import 'core/supabase_config.dart';
import 'features/auth/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  StreamSubscription<AuthState>? _authSubscription;
  bool _introComplete = false;
  Session? _session;

  @override
  void initState() {
    super.initState();
    if (isSupabaseConfigured) {
      final auth = Supabase.instance.client.auth;
      _session = auth.currentSession;
      _authSubscription = auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        setState(() => _session = data.session);
      });
    }
    _introTimer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      setState(() => _introComplete = true);
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_introComplete) return const SplashScreen();
    if (!isSupabaseConfigured || _session == null) return const AuthScreen();
    return const AppShell();
  }
}
