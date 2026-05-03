import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color lightGreen = Color(0xFF4ADE80);
  static const Color darkGreen = Color(0xFF14532D);
  static const Color emerald = Color(0xFF10B981);
  static const Color bgGreen = Color(0xFFF0FDF4);
  static const Color bgEmerald = Color(0xFFECFDF5);
  static const Color red = Color(0xFFDC2626);
  static const Color lightRed = Color(0xFFFEF2F2);
  static const Color orange = Color(0xFFEA580C);
  static const Color lightOrange = Color(0xFFFFF7ED);
  static const Color blue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color lightPurple = Color(0xFFF5F3FF);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF9FAFB);

  // Builds and returns the app's global Material theme with Cairo font, green color scheme, and styled components
  static ThemeData get theme {
    final cairoBase = GoogleFonts.cairoTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: emerald,
        surface: Colors.white,
        error: red,
      ),
      scaffoldBackgroundColor: bgGreen,
      textTheme: cairoBase.copyWith(
        headlineLarge: cairoBase.headlineLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 28, color: darkGreen),
        headlineMedium: cairoBase.headlineMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 24, color: darkGreen),
        headlineSmall: cairoBase.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20, color: darkGreen),
        titleLarge: cairoBase.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 18, color: darkGreen),
        titleMedium: cairoBase.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16, color: darkGreen),
        bodyLarge: cairoBase.bodyLarge?.copyWith(fontSize: 16, color: const Color(0xFF374151)),
        bodyMedium: cairoBase.bodyMedium?.copyWith(fontSize: 14, color: const Color(0xFF374151)),
        bodySmall: cairoBase.bodySmall?.copyWith(fontSize: 12, color: const Color(0xFF6B7280)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
    );
  }
}