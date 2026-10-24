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
  try {
    await AppAccessibilitySettings.load().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Default text scale applies; a local preference must never block startup.
  }

  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: normalizedSupabaseUrl,
        publishableKey: supabaseAnonKey.trim(),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Without this, a failed or slow initialization leaves the app on the
      // launch logo forever because runApp is never reached.
      supabaseInitializationError =
          'No se pudo iniciar la conexión con el servidor. Revisá tu conexión e intentá abrir la app de nuevo.';
    }
  }

  runApp(const ProviderScope(child: MiltvPlusApp()));
}
