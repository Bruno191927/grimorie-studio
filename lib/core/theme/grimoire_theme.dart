import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GrimoireTheme {
  // Brand Backgrounds & Surfaces (Faithful to the Reference Image)
  static const Color bgCanvas = Color(0xFF0B0E14);
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color surfacePanel = Color(0xFF101420);
  static const Color surfaceCard = Color(0xFF131622);
  static const Color surfaceCardHover = Color(0xFF1A1F33);
  static const Color surfaceElevated = Color(0xFF191D2F);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFF1E2337);
  static const Color borderStrong = Color(0xFF2E3550);
  static const Color borderFocus = Color(0xFF7C3AED);

  // Accent Colors & Brand Gradients
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgCanvas,
      primaryColor: accentPurple,
      colorScheme: const ColorScheme.dark(
        primary: accentPurple,
        secondary: accentIndigo,
        surface: surfacePanel,
        error: accentPink,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141824),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentPurple, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(6.0),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return accentPurple.withValues(alpha: 0.85);
          }
          return accentPurple.withValues(alpha: 0.45);
        }),
        trackColor: WidgetStateProperty.all(const Color(0xFF131522)),
        trackBorderColor: WidgetStateProperty.all(borderSubtle),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderStrong, width: 1),
        ),
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        actionTextColor: accentCyan,
        showCloseIcon: true,
        closeIconColor: textMuted,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}
