import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the UTM BusTracker mobile app.
/// Source: redesign-preview/ (HANDOFF.md §2).
class AppTheme {
  // ── Brand ────────────────────────────────────────────────────────
  static const crimson     = Color(0xFF8B1A2B);
  static const crimsonDeep = Color(0xFF5E1220);
  static const accent      = Color(0xFFD42A2A);

  // ── Route palette ────────────────────────────────────────────────
  static const routeA = Color(0xFF10A65A); // green
  static const routeB = Color(0xFF2563EB); // blue
  static const routeC = Color(0xFFD42A2A); // red — overrides mock_data orange

  // ── Ink / neutrals ───────────────────────────────────────────────
  static const ink900 = Color(0xFF1A1413);
  static const ink700 = Color(0xFF3F3635);
  static const ink500 = Color(0xFF6B5F5D);
  static const ink400 = Color(0xFF928683);
  static const ink300 = Color(0xFFBDB3B0);
  static const paper  = Color(0xFFFAF7F4);

  // ── Occupancy thresholds ─────────────────────────────────────────
  static const occLow  = routeA;            // <50%
  static const occMid  = Color(0xFFE08A00); // 50–75%
  static const occHigh = accent;            // >75%

  /// Returns the threshold color for `0..1` occupancy.
  static Color occupancyColor(double occupancy) {
    if (occupancy > 0.75) return occHigh;
    if (occupancy > 0.50) return occMid;
    return occLow;
  }

  // ── Typography ───────────────────────────────────────────────────
  static TextStyle plate({double size = 15, Color color = ink900}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size * 0.04,
      color: color,
    );
  }

  static TextStyle label({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color color = ink500,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ── Theme ────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: crimson,
        primary: crimson,
        secondary: accent,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: paper,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: ink900,
        displayColor: ink900,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: crimson,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconTheme: const IconThemeData(color: ink700),
    );
  }
}
