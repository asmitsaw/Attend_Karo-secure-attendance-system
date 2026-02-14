import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ──────────────────────────────────────────────
  // Brand Colors – matching Stitch design tokens
  // ──────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF19287B);
  static const Color primaryLight = Color(0xFF3042A3);
  static const Color primaryDark = Color(0xFF0F1A54);

  static const Color accentPurple = Color(0xFF6200EA);
  static const Color accentPurpleHover = Color(0xFF5000BE);

  static const Color successColor = Color(0xFF00C853);
  static const Color dangerColor = Color(0xFFD50000);
  static const Color warningColor = Color(0xFFFF9800);

  static const Color backgroundLight = Color(0xFFF6F6F8);
  static const Color backgroundDark = Color(0xFF121420);

  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E2235);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);

  // ──────────────────────────────────────────────
  // Light Theme
  // ──────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundLight,

    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentPurple,
      tertiary: successColor,
      error: dangerColor,
      surface: surfaceLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
    ),

    // Typography — Lexend everywhere
    textTheme: GoogleFonts.lexendTextTheme().copyWith(
      displayLarge: GoogleFonts.lexend(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.lexend(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.lexend(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.lexend(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.lexend(fontSize: 16, color: textPrimary),
      bodyMedium: GoogleFonts.lexend(fontSize: 14, color: textSecondary),
      bodySmall: GoogleFonts.lexend(fontSize: 12, color: textSecondary),
      labelLarge: GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      labelMedium: GoogleFonts.lexend(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.lexend(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textTertiary,
        letterSpacing: 0.6,
      ),
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        shadowColor: accentPurple.withOpacity(0.3),
        textStyle: GoogleFonts.lexend(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: dangerColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: dangerColor, width: 2),
      ),
      hintStyle: GoogleFonts.lexend(
        color: const Color(0xFF9E9E9E),
        fontSize: 14,
      ),
      labelStyle: GoogleFonts.lexend(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: surfaceLight,
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: primaryColor,
      unselectedItemColor: textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerColor: const Color(0xFFF0F0F0),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFF0F0F0),
      thickness: 1,
    ),
  );
}
