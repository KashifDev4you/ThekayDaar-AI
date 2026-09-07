import 'package:flutter/material.dart';

/// Emerald Estate design system for Thekaydaar.pk.
///
/// Deep emerald green + premium gold on a warm ivory background.
/// All screens should pull colors, radii, and spacing from here instead
/// of hardcoding values.
class AppTheme {
  // ── Emerald Estate palette ──────────────────────────────
  static const Color emerald = Color(0xFF0E3B2E);
  static const Color emeraldMid = Color(0xFF1A5C46);
  static const Color emeraldSoft = Color(0xFFE7F2ED);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldDark = Color(0xFFA8861D);
  static const Color goldSoft = Color(0xFFFBF6E3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF7F5EF);
  static const Color textBody = Color(0xFF1F2A26);
  static const Color textMuted = Color(0xFF5D6B64);
  static const Color border = Color(0xFFE3E0D5);
  static const Color textFaint = Color(0xFFA6B2AB);

  // ── Semantic status colors (kept separate from brand) ────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFA8861D);
  static const Color warningSoft = Color(0xFFFBF6E3);
  static const Color warningBorder = Color(0xFFE6D694);

  // ── Legacy names (keep existing code compiling) ─────────
  static const Color navy = emerald;
  static const Color navyMid = emeraldMid;
  static const Color amber = gold;
  static const Color amberDark = goldDark;

  // ── Shared radii / spacing rhythm ───────────────────────
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double spaceUnit = 8;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: bg,
    primaryColor: emerald,
    colorScheme: const ColorScheme.light(
      primary: emerald,
      onPrimary: Colors.white,
      primaryContainer: emeraldSoft,
      onPrimaryContainer: emerald,
      secondary: gold,
      onSecondary: emerald,
      secondaryContainer: goldSoft,
      onSecondaryContainer: goldDark,
      surface: surface,
      onSurface: textBody,
      onSurfaceVariant: textMuted,
      outline: border,
      error: Color(0xFFDC2626),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: emerald,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: emerald,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: emerald,
        side: const BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: emerald,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: emerald,
      elevation: 2,
      shape: StadiumBorder(),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: goldSoft,
      disabledColor: bg,
      labelStyle: const TextStyle(color: textBody, fontSize: 13, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: goldDark, fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      selectedItemColor: gold,
      unselectedItemColor: textMuted,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
      ),
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textBody),
      subtitleTextStyle: TextStyle(fontSize: 13, color: textMuted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return gold;
        return surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return gold.withValues(alpha: 0.3);
        return border;
      }),
      trackOutlineColor: WidgetStateProperty.all(border),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: gold,
      labelColor: emerald,
      unselectedLabelColor: textMuted,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: emerald,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textBody,
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      displayMedium: TextStyle(
        color: textBody,
        fontWeight: FontWeight.w700,
        fontSize: 24,
      ),
      headlineLarge: TextStyle(
        color: textBody,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      headlineMedium: TextStyle(
        color: textBody,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleLarge: TextStyle(
        color: textBody,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyLarge: TextStyle(color: textBody, fontSize: 15),
      bodyMedium: TextStyle(color: textMuted, fontSize: 13),
      bodySmall: TextStyle(color: textMuted, fontSize: 11),
    ),
  );
}
