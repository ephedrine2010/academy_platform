import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nahdi Academy brand palette, sampled from the official mark (deep-teal
/// mosaic graduation cap). Use [AppColors.accents] for category tags and status
/// chips where a splash of the mosaic is wanted.
class AppColors {
  AppColors._();

  // Core teal identity.
  static const Color teal = Color(0xFF00444F);
  static const Color tealDark = Color(0xFF00333B);
  static const Color tealLight = Color(0xFF0A6A74);

  // Neutral surfaces.
  static const Color canvas = Color(0xFFFBFAF7); // warm paper
  static const Color surface = Colors.white;

  // Body text.
  static const Color ink = Color(0xFF111E20);

  // Mosaic accents — sampled from the cap.
  static const Color red = Color(0xFFE02234);
  static const Color orange = Color(0xFFF0612F);
  static const Color yellow = Color(0xFFF4A81E);
  static const Color lime = Color(0xFFC9D634);
  static const Color green = Color(0xFF6FB840);
  static const Color sky = Color(0xFF2FA8D8);
  static const Color blue = Color(0xFF1A7CC0);
  static const Color purple = Color(0xFF9C3690);

  /// Stable, ordered accent list for tinting items by index (regions, tags…).
  static const List<Color> accents = [
    blue,
    green,
    orange,
    purple,
    red,
    yellow,
    sky,
    lime,
  ];

  /// A deterministic accent for a given string key (region/trainer name).
  static Color accentFor(String key) {
    if (key.isEmpty) return teal;
    final hash = key.codeUnits.fold<int>(0, (a, c) => a + c);
    return accents[hash % accents.length];
  }
}

/// Builds the app's light theme around the Nahdi Academy teal identity.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      brightness: Brightness.light,
    ).copyWith(
      // onBackground is a deprecated alias of onSurface; setting onSurface
      // colours both background and surface text as ink.
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: _textTheme(),
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

  /// Brand typography: Bricolage Grotesque for display/headline/title (w700–w800),
  /// Manrope for body/label.
  static TextTheme _textTheme() {
    final base = ThemeData.light().textTheme;
    final display = GoogleFonts.bricolageGrotesqueTextTheme(base);
    final body = GoogleFonts.manropeTextTheme(base);
    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: body.bodyLarge,
      bodyMedium: body.bodyMedium,
      bodySmall: body.bodySmall,
      labelLarge: body.labelLarge,
      labelMedium: body.labelMedium,
      labelSmall: body.labelSmall,
    );
  }
}
