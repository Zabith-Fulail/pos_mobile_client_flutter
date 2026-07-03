import 'package:flutter/material.dart';

class AppTheme {
  // === DARK BACKGROUND PALETTE ===
  static const Color bgBase = Color(0xFF0D0F1A);
  static const Color bgSurface = Color(0xFF151722);
  static const Color bgCard = Color(0xFF1C1E2C);
  static const Color bgCardElevated = Color(0xFF242638);
  static const Color bgBorder = Color(0xFF2E3148);

  // === BRAND PALETTE ===
  static const Color gold = Color(0xFFC8973A);
  static const Color goldLight = Color(0xFFE8C870);
  static const Color goldDim = Color(0xFF8C6828);
  static const Color green = Color(0xFF6DB352);
  static const Color greenDim = Color(0xFF3E6630);
  static const Color red = Color(0xFFE85A4F);
  static const Color blue = Color(0xFF7B9FD9);

  // === TEXT PALETTE ===
  static const Color textPrimary = Color(0xFFF0EEE8);
  static const Color textSecondary = Color(0xFF9B9BA8);
  static const Color textHint = Color(0xFF5A5C6E);
  static const Color textOnGold = Color(0xFF1A0E00);

  // === GRADIENTS ===
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFC8973A), Color(0xFFE8C870)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    colors: [Color(0xFFE8C870), Color(0xFFC8973A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0D0F1A), Color(0xFF13152A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1E2C), Color(0xFF242638)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF6DB352), Color(0xFF90C068)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === THEME DATA ===
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgBase,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: green,
        surface: bgCard,
        error: red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerColor: bgBorder,
      cardColor: bgCard,
    );
  }


  static InputDecoration inputDecoration({required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppTheme.bgCardElevated,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.gold, size: 20) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.bgBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.bgBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.red),
      ),
    );
  }
}
