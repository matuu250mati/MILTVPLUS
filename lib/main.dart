import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fvp/fvp.dart' as fvp;

import 'app.dart';
import 'core/accessibility_settings.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the official video_player backend on Android/iOS/web, and register
  // the compatible native backend on Windows, macOS and Linux.
  fvp.registerWith(options: const {'platforms': ['windows', 'macos', 'linux']});

  // Render Flutter immediately. Preferences and Supabase must not prevent the
  // first frame from appearing.
  runApp(const ProviderScope(child: _StartupGate()));
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  static const _startupTimeout = Duration(seconds: 8);

  Future<void>? _supabaseInitialization;
  bool _ready = false;
  bool _failed = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _failed = false;
    });

    // Accessibility settings have safe defaults. A preferences failure should
    // not block startup.
    unawaited(AppAccessibilitySettings.load().catchError((Object _) {}));

    if (!isSupabaseConfigured) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _retrying = false;
      });
      return;
    }

    // Reuse an in-flight initialization after a UI timeout; calling
    // Supabase.initialize twice while the first call is still running is unsafe.
    final initialization = _supabaseInitialization ??= Supabase.initialize(
      url: normalizedSupabaseUrl,
      publishableKey: supabaseAnonKey.trim(),
    );

    try {
      await initialization.timeout(_startupTimeout);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _retrying = false;
        _failed = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _failed = true;
      });
      // The original initialization may still complete after the UI timeout.
      // Observe its completion and transition automatically if it succeeds.
      unawaited(initialization.then((_) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _retrying = false;
          _failed = false;
        });
      }, onError: (Object error, StackTrace stack) {
        // The error is presented by the retry screen; avoid an unhandled
        // asynchronous error from the background observer.
      }));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _failed = true;
        // A completed initialization failure can be retried. If it timed out,
        // the future is retained above to avoid duplicate initialization.
        _supabaseInitialization = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MiltvPlusApp();

    return MaterialApp(
      title: 'MILTVPLUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF050805),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.live_tv,
                      size: 64,
                      color: Color(0xFF39D353),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _failed
                          ? 'No se pudo iniciar la conexión'
                          : 'Iniciando MILTVPLUS…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _failed
                          ? 'La aplicación sigue abierta, pero el servicio no respondió. Revisá la conexión e intentá nuevamente.'
                          : 'Preparando la aplicación.',
                      textAlign: TextAlign.center,
                    ),
                    if (_retrying) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(
                        color: Color(0xFF39D353),
                      ),
                    ],
                    if (_failed) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _retrying ? null : _start,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
