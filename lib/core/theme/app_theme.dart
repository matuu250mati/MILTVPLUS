import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF080A10);
  static const panel = Color(0xFF111521);
  static const accent = Color(0xFFB8FF35);
  static const muted = Color(0xFF9AA3B5);

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: Color(0xFF6C7BFF),
      surface: panel,
      error: Color(0xFFFF5B70),
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF171C2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: muted),
    ),
  );
}
