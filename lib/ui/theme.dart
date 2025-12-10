import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/flavor_config.dart';

class AppTheme {
  /// Get the light theme for the current brand
  static ThemeData get lightTheme {
    final brandConfig = FlavorConfig.instance.brandConfig;
    return _buildLightTheme(
      primaryColor: brandConfig.primaryColor,
      secondaryColor: brandConfig.secondaryColor,
    );
  }

  /// Build a light theme with custom colors
  static ThemeData _buildLightTheme({
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final brandSurface = Color(0xFFF9FBF9);
    final brandPrimaryContainer = Color.alphaBlend(
      primaryColor.withOpacity(0.8),
      Colors.black.withOpacity(0.2),
    );

    final lightScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: brandPrimaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black87,
      background: brandSurface,
      onBackground: Colors.black87,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightScheme.background,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: lightScheme.onBackground,
        displayColor: lightScheme.onBackground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightScheme.primary,
        ),
        iconTheme: IconThemeData(color: lightScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightScheme.primary,
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
