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
  // the compatible native backend on Windows and macOS. Linux desktop is not a supported target.
  fvp.registerWith(options: const {'platforms': ['windows', 'macos']});
  // Never hold Android's native launch screen hostage to preferences or backend startup.
  try {
    await AppAccessibilitySettings.load().timeout(const Duration(seconds: 5));
  } catch (_) {
    // Accessibility preferences are optional; use defaults if storage is unavailable.
  }

  supabaseClientInitialized = false;
  supabaseInitializationFailure = null;
  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: normalizedSupabaseUrl,
        publishableKey: supabaseAnonKey.trim(),
      ).timeout(const Duration(seconds: 12));
      supabaseClientInitialized = true;
    } catch (error) {
      supabaseInitializationFailure = _startupErrorMessage(error);
    }
  }

  // This must run even if Supabase is offline/misconfigured so the user sees
  // an actionable error instead of an endless logo/native splash.
  runApp(const ProviderScope(child: MiltvPlusApp()));
}

String _startupErrorMessage(Object error) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('socket') || detail.contains('network') ||
      detail.contains('connection') || detail.contains('timed out') ||
      detail.contains('timeout') || detail.contains('host lookup')) {
    return 'No hay conexión con el servicio. Revisá internet y tocá reintentar.';
  }
  return 'No se pudo iniciar el servicio de acceso. Revisá la conexión e intentá de nuevo.';
}
}
