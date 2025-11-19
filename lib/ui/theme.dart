import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _brandPrimary = Color(0xFF54A079);
  static const _brandSecondary = Color(0xFF1F1B20);
  static const _brandSurface = Color(0xFFF9FBF9);
  static const _brandPrimaryContainer = Color(0xFF3B7C5F);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _brandPrimary,
    brightness: Brightness.light,
  ).copyWith(
    primary: _brandPrimary,
    onPrimary: Colors.white,
    primaryContainer: _brandPrimaryContainer,
    onPrimaryContainer: Colors.white,
    secondary: _brandSecondary,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
    background: _brandSurface,
    onBackground: Colors.black87,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    primaryColor: _brandPrimary,
    scaffoldBackgroundColor: _lightScheme.background,
    textTheme: GoogleFonts.robotoTextTheme().apply(
      bodyColor: _lightScheme.onBackground,
      displayColor: _lightScheme.onBackground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _lightScheme.onSurface,
      elevation: 0,
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _lightScheme.primary,
      ),
      iconTheme: IconThemeData(color: _lightScheme.primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightScheme.primary,
        foregroundColor: _lightScheme.onPrimary,
        textStyle:
            GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _lightScheme.primary,
        foregroundColor: _lightScheme.onPrimary,
        textStyle:
            GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightScheme.primary,
        textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandPrimary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: _lightScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
  );
}
