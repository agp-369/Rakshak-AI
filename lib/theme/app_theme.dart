import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // India-inspired palette — saffron, teal, deep navy
  static const Color saffron = Color(0xFFE8590C);
  static const Color saffronLight = Color(0xFFFF6B35);
  static const Color saffronDark = Color(0xFFC22502);
  static const Color teal = Color(0xFF099268);
  static const Color tealLight = Color(0xFF12B886);
  static const Color navy = Color(0xFF0A0B0E);
  static const Color surface = Color(0xFF141517);
  static const Color surfaceLight = Color(0xFF1C1E21);
  static const Color chakraBlue = Color(0xFF1971C2);
  static const Color white = Color(0xFFF8F9FA);
  static const Color grey = Color(0xFF868E96);
  static const Color red = Color(0xFFE03131);
  static const Color yellow = Color(0xFFFCC419);
  static const Color green = Color(0xFF2F9E44);
  static const Color black = Color(0xFF000000);

  // Triage colors (standard medical)
  static Color triageImmediate = red;
  static Color triageDelayed = const Color(0xFFE6A800);
  static Color triageMinimal = green;
  static Color triageDeceased = const Color(0xFF495057);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: const ColorScheme.dark(
        primary: saffron,
        secondary: teal,
        surface: surface,
        onPrimary: white,
        onSecondary: white,
        onSurface: white,
        error: red,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: white,
        displayColor: saffronLight,
        fontFamily: 'sans-serif',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: saffronLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: saffronLight),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2E33), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: saffron,
        labelStyle: const TextStyle(fontSize: 12, color: white),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2C2E33)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: saffron, width: 1.5),
        ),
        labelStyle: const TextStyle(color: grey),
        hintStyle: const TextStyle(color: grey),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2C2E33)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: const TextStyle(color: white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
