import 'package:flutter/material.dart';

/// CleanSpot Color Palette
/// Primary: Health Teal (#00897B)
/// Secondary/Warning: Alert Amber (#FFB300)
/// Error/Hazard: Hazard Red (#E53935)
/// Dark Background: Dark Charcoal (#1E293B)
class AppColors {
  AppColors._();

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color primaryTealDark = Color(0xFF00695C);
  static const Color primaryTealLight = Color(0xFF4DB6AC);

  static const Color alertAmber = Color(0xFFFFB300);
  static const Color hazardRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF43A047);

  static const Color darkCharcoal = Color(0xFF1E293B);
  static const Color darkCharcoalSurface = Color(0xFF0F172A);
  static const Color darkCharcoalCard = Color(0xFF334155);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryTeal,
      primary: AppColors.primaryTeal,
      secondary: AppColors.alertAmber,
      error: AppColors.hazardRed,
      surface: AppColors.lightSurface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryTeal,
      primary: AppColors.primaryTealLight,
      secondary: AppColors.alertAmber,
      error: AppColors.hazardRed,
      surface: AppColors.darkCharcoalCard,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkCharcoalSurface,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCharcoalCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
