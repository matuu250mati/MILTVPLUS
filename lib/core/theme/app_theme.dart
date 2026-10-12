import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF080A10);
  static const panel = Color(0xFF111521);

  // Paleta de MIL TV Plus: azul y blanco argentinos con acento celeste.
  // Equivale a los dos estados del selector Android recibido:
  // seleccionado -> selectedAccent; normal -> accent.
  static const selectedAccent = Color(0xFF74D7FF);
  static const accent = Color(0xFFB8FF35);
  static const muted = Color(0xFF9AA3B5);

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: selectedAccent,
      secondary: accent,
      surface: panel,
      error: Color(0xFFFF5B70),
    ),
    focusColor: selectedAccent.withValues(alpha: 0.18),
    hoverColor: selectedAccent.withValues(alpha: 0.10),
    splashColor: selectedAccent.withValues(alpha: 0.14),
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
