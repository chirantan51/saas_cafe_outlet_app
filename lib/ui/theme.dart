import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color(0xFF54A079), // ✅ Primary Green
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.robotoTextTheme().apply(
      bodyColor: Colors.grey[800], // ✅ Default Text Color
      displayColor: Colors.grey[800], // ✅ Headings Color
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor:  Colors.black,
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF54A079),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF54A079)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF54A079), // ✅ Button Primary Color
        foregroundColor: Colors.white, // ✅ Button Text Color
        textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1F1B20), // ✅ Secondary Color
        textStyle: GoogleFonts.roboto(fontSize: 16),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF54A079), width: 2),
      ),
    ),
  );
}
