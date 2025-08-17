import 'package:flutter/material.dart';

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFA7C7FF), // light-blue accent
      onPrimary: Color(0xFF0B2545),
      secondary: Color(0xFFA7C7FF),
      onSecondary: Color(0xFF0B2545),
      surface: Color(0xFF2F2F2F), // dialog panel background
      onSurface: Color(0xFFE5E7EB), // labels/text
      error: Color(0xFFEF4444),
      onError: Colors.white,
      primaryContainer: Color(0xFF9DBDFF),
      onPrimaryContainer: Color(0xFF0B2545),
      secondaryContainer: Color(0xFF9DBDFF),
      onSecondaryContainer: Color(0xFF0B2545),
      surfaceTint: Color(0xFFA7C7FF),
      outline: Color(0xFF4B5563),
      outlineVariant: Color(0xFF374151),
      tertiary: Color(0xFFA7C7FF),
      onTertiary: Color(0xFF0B2545),
      scrim: Colors.black54,
      inverseSurface: Color(0xFFE5E7EB),
      onInverseSurface: Color(0xFF111827),
      inversePrimary: Color(0xFF5B8DEF),
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
        foregroundColor: const Color(0xFFA7C7FF), // OK/Cancel
      ),
    ),
    useMaterial3: true,
  );
}
