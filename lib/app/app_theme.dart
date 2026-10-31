import 'package:flutter/material.dart';

abstract final class AppColors {
  static const steel900 = Color(0xFF131C22);
  static const steel800 = Color(0xFF1B2B33);
  static const steel700 = Color(0xFF25404B);
  static const steel500 = Color(0xFF5C7885);
  static const steel200 = Color(0xFFCFDBDE);
  static const steel100 = Color(0xFFE4EBEC);
  static const paper = Color(0xFFEEF1EF);
  static const orange = Color(0xFFE2621C);
  static const orangeDark = Color(0xFFB94C14);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: AppColors.steel700,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.steel900,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.steel200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.steel200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.steel200),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
