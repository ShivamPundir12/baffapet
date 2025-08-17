import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF5B8DEF), // accent (selected day, clock hand)
      onPrimary: Colors.white,
      secondary: Color(0xFF5B8DEF),
      onSecondary: Colors.white,
      surface: Color(0xFFF8FAFC), // dialog background
      onSurface: Color(0xFF0F172A), // dialog text
      error: Color(0xFFEF4444),
      onError: Colors.white,
      primaryContainer: Color(0xFF9DBDFF),
      onPrimaryContainer: Color(0xFF0B2545),
      secondaryContainer: Color(0xFF9DBDFF),
      onSecondaryContainer: Color(0xFF0B2545),
      surfaceTint: Color(0xFF5B8DEF),
      outline: Color(0xFFE2E8F0),
      outlineVariant: Color(0xFFD1D5DB),
      tertiary: Color(0xFF5B8DEF),
      onTertiary: Colors.white,
      scrim: Colors.black54,
      inverseSurface: Color(0xFF111827),
      onInverseSurface: Color(0xFFE5E7EB),
      inversePrimary: Color(0xFF3B82F6),
      shadow: Colors.black,
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 8,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF5B8DEF), // OK/Cancel
      ),
    ),
    useMaterial3: true,
  );
}
