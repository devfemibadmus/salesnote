import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FEB)),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
        // IMPORTANT: Size.fromHeight() sets width to infinity, which breaks in Row layouts.
        // Keep a consistent height but allow width to be constrained by the parent.
        style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Same rationale as filledButtonTheme.
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
      ),
    );
  }
}
