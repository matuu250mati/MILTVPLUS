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

  // Preferences are optional. A platform/plugin delay must never prevent Flutter
  // from mounting the app and replacing the native launch logo.
  try {
    await AppAccessibilitySettings.load().timeout(const Duration(seconds: 2));
  } catch (_) {
    // Defaults are already valid; continue with the normal UI.
  }

  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: normalizedSupabaseUrl,
        publishableKey: supabaseAnonKey.trim(),
      ).timeout(const Duration(seconds: 8));
    } catch (error) {
      // Keep the original failure visible in QA instead of masking DNS,
      // storage, or initialization errors behind a generic connection message.
      supabaseStartupFailed = true;
      supabaseStartupError = error.toString();
    }
  }

  runApp(const ProviderScope(child: MiltvPlusApp()));
}
