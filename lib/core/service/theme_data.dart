import 'package:flutter/material.dart';

final ThemeData posTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: const Color(0xFF76D61D),
  scaffoldBackgroundColor: const Color(0xFFF4F5F7),
  splashColor: const Color(0xFF76D61D).withValues(alpha: 0.1),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF76D61D),
    onPrimary: Colors.white,
    secondary: Color(0xFF2D3436),
    error: Color(0xFFE53935),
    surface: Colors.white,
    onSurface: Color(0xFF2D3436),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF76D61D), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF76D61D),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),

  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w800,
      color: Color(0xFF2D3436),
      fontSize: 24,
    ),
    bodyLarge: TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xFF2D3436),
      fontSize: 16,
    ),
    bodyMedium: TextStyle(color: Colors.grey, fontSize: 14),
    titleLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Color(0xFF2D3436),
    ),
  ),
);
