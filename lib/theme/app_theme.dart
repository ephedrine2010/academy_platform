import 'package:flutter/material.dart';

/// Nahdi brand palette, taken from the company logo (deep teal field +
/// multicolour mosaic heart). Use [AppColors.accents] for category tags and
/// status chips where a splash of the mosaic is wanted.
class AppColors {
  AppColors._();

  // Core teal identity.
  static const Color teal = Color(0xFF0E5257);
  static const Color tealDark = Color(0xFF0A3B3F);
  static const Color tealLight = Color(0xFF1B7A80);

  // Neutral surfaces.
  static const Color canvas = Color(0xFFF4F7F7);
  static const Color surface = Colors.white;

  // Mosaic accents.
  static const Color red = Color(0xFFE2231A);
  static const Color orange = Color(0xFFF58220);
  static const Color yellow = Color(0xFFFBB034);
  static const Color green = Color(0xFF3DAE2B);
  static const Color blue = Color(0xFF00A0DF);
  static const Color purple = Color(0xFF8E2D8C);

  /// Stable, ordered accent list for tinting items by index (regions, tags…).
  static const List<Color> accents = [
    blue,
    green,
    orange,
    purple,
    red,
    yellow,
  ];

  /// A deterministic accent for a given string key (region/contractor name).
  static Color accentFor(String key) {
    if (key.isEmpty) return teal;
    final hash = key.codeUnits.fold<int>(0, (a, c) => a + c);
    return accents[hash % accents.length];
  }
}

/// Builds the app's light theme around the Nahdi teal identity.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.tealDark,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6)),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        indicatorColor: AppColors.tealLight,
        useIndicator: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}
