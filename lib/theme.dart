import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/features_provider.dart';

// =============================================================================
// FALCON EYE V42 — UNIFIED THEME SYSTEM
// One single theme choice controls the entire app's colors across all pages
// =============================================================================

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
}

class AppRadius {
  static const double xs = 2.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 9999.0;
}

// =============================================================================
// V42: DYNAMIC THEME BUILDER — Generates ThemeData from FalconTheme
// =============================================================================

ThemeData buildFalconTheme(FalconTheme ft) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: ft.primary,
      onPrimary: Colors.black,
      primaryContainer: ft.primary.withValues(alpha: 0.15),
      onPrimaryContainer: ft.primary,
      secondary: ft.secondary,
      onSecondary: Colors.black,
      secondaryContainer: ft.secondary.withValues(alpha: 0.15),
      onSecondaryContainer: ft.secondary,
      tertiary: ft.accent,
      onTertiary: Colors.black,
      error: const Color(0xFFFF6699),
      onError: Colors.black,
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: ft.background,
      onSurface: ft.primary.withValues(alpha: 0.9),
      surfaceContainerHighest: ft.surface,
      onSurfaceVariant: ft.primary.withValues(alpha: 0.6),
      outline: ft.primary.withValues(alpha: 0.3),
      shadow: ft.primary,
      inverseSurface: ft.primary,
      onInverseSurface: Colors.black,
      inversePrimary: ft.secondary,
    ),
    scaffoldBackgroundColor: ft.background,
    textTheme: _buildTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ft.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ft.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: ft.primary.withValues(alpha: 0.2)),
      ),
    ),
    iconTheme: IconThemeData(color: ft.primary),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: ft.background,
      selectedItemColor: ft.primary,
      unselectedItemColor: ft.primary.withValues(alpha: 0.3),
      type: BottomNavigationBarType.fixed,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? ft.primary : Colors.white24),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? ft.primary.withValues(alpha: 0.3) : Colors.white12),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: ft.primary,
      inactiveTrackColor: ft.primary.withValues(alpha: 0.15),
      thumbColor: ft.primary,
      overlayColor: ft.primary.withValues(alpha: 0.12),
      trackHeight: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ft.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: ft.primary, width: 1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ft.surface,
      contentTextStyle: TextStyle(color: ft.primary),
    ),
  );
}

/// Legacy compatibility — used by splash only before provider is ready
ThemeData get darkTheme => buildFalconTheme(FalconTheme.neoGreen);

// Legacy color references for backward compatibility
class FalconColors {
  static const darkPrimary = Color(0xFF00FF66);
  static const darkOnSurface = Color(0xFFE4FFF0);
  static const darkOnSurfaceVariant = Color(0xFFA4CBB4);
  static const darkOutline = Color(0xFF2E5A42);
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF000000);
  static const darkSurfaceVariant = Color(0xFF0D1F15);

  // Light theme legacy (backward compat for pages)
  static const lightPrimary = Color(0xFF00F5FF);
  static const lightSecondary = Color(0xFFFF00FF);
  static const lightOnPrimary = Color(0xFF003840);
  static const lightOnSecondary = Color(0xFF400040);
  static const lightBackground = Color(0xFFF0F0F5);
  static const lightOnBackground = Color(0xFF0A0A0F);
  static const lightSurface = Color(0xFFF0F0F5);
  static const lightOnSurface = Color(0xFF0A0A0F);
  static const lightSurfaceVariant = Color(0xFFD8D8E0);
  static const lightOnSurfaceVariant = Color(0xFF44474E);
  static const lightOutline = Color(0xFF75757F);
}

TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: GoogleFonts.orbitron(fontSize: 57, fontWeight: FontWeight.w400, height: 1.12),
    displayMedium: GoogleFonts.orbitron(fontSize: 45, fontWeight: FontWeight.w400, height: 1.16),
    displaySmall: GoogleFonts.orbitron(fontSize: 36, fontWeight: FontWeight.w400, height: 1.22),
    headlineLarge: GoogleFonts.orbitron(fontSize: 32, fontWeight: FontWeight.w400, height: 1.25),
    headlineMedium: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.w400, height: 1.29),
    headlineSmall: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.w400, height: 1.33),
    titleLarge: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.w400, height: 1.27),
    titleMedium: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
    titleSmall: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.w500, height: 1.43),
    labelLarge: GoogleFonts.exo2(fontSize: 14, fontWeight: FontWeight.w500, height: 1.43),
    labelMedium: GoogleFonts.exo2(fontSize: 12, fontWeight: FontWeight.w500, height: 1.33),
    labelSmall: GoogleFonts.exo2(fontSize: 11, fontWeight: FontWeight.w500, height: 1.45),
    bodyLarge: GoogleFonts.exo2(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: GoogleFonts.exo2(fontSize: 14, fontWeight: FontWeight.w400, height: 1.43),
    bodySmall: GoogleFonts.exo2(fontSize: 12, fontWeight: FontWeight.w400, height: 1.33),
  );
}

extension TextStyleExtensions on TextStyle {
  TextStyle get mono => GoogleFonts.robotoMono(textStyle: this);
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get w900 => copyWith(fontWeight: FontWeight.w900);
}
