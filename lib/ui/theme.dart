/// Coach Loop theme: dark, with the PWA's lime accent (#c6ff4a).
library;

import 'package:flutter/material.dart';

/// The signature lime accent, matching the PWA.
const Color limeAccent = Color(0xFFC6FF4A);

ThemeData coachLoopTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme = ColorScheme.dark(
    primary: limeAccent,
    onPrimary: const Color(0xFF11140D),
    secondary: limeAccent,
    surface: const Color(0xFF171916),
    surfaceContainerHighest: const Color(0xFF20231E),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF101210),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101210),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF171916),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: limeAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? limeAccent : null,
      ),
      checkColor: WidgetStateProperty.all(const Color(0xFF11140D)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
