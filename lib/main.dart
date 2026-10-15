import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/accessibility_settings.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAccessibilitySettings.load();

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: normalizedSupabaseUrl,
      publishableKey: supabaseAnonKey.trim(),
    );
  }

  runApp(const ProviderScope(child: MiltvPlusApp()));
}
