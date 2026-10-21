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
  await AppAccessibilitySettings.load();

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: normalizedSupabaseUrl,
      publishableKey: supabaseAnonKey.trim(),
    );
  }

  runApp(const ProviderScope(child: MiltvPlusApp()));
}
