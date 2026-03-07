import 'package:flutter/material.dart';

class AppTheme {
  static const Color appBackground = Color(0xFFF3F4F6);

  static ThemeData light() {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FEB)),
      useMaterial3: true,
      scaffoldBackgroundColor: appBackground,
      canvasColor: appBackground,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: appBackground,
        contentTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: const Color(0xFF1F6FEB),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD8E2EE)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothPageTransitionsBuilder(),
        },
      ),
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

    final text = theme.textTheme;
    return theme.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontSize: 30, fontWeight: FontWeight.w800),
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
        headlineSmall: text.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: text.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
        bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.35),
        labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: text.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        labelSmall: text.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;

    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.03, 0),
      end: Offset.zero,
    ).animate(fade);
    final scale = Tween<double>(begin: 0.995, end: 1.0).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
