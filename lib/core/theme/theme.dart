import 'package:flutter/material.dart';

/// 🌈 Global color palette & app theme for Jibli

class AppColors {
  // Primary Brand Colors - Fresh and Appetizing
  static const Color primary = Color(0xFF00A878);      // Fresh Teal Green - Trust, freshness, healthy
  static const Color accent = Color(0xFFFF6B35);       // Vibrant Orange - Energy, appetite, excitement
  static const Color secondary = Color(0xFF004E64);    // Deep Teal - Stability, professionalism

  // Status Colors - Clear and Intuitive
  static const Color success = Color(0xFF10B981);      // Modern Green - Success, delivered
  static const Color danger = Color(0xFFEF4444);       // Modern Red - Urgent, error
  static const Color warning = Color(0xFFFBBF24);      // Warm Yellow - Warning, pending
  static const Color info = Color(0xFF3B82F6);         // Modern Blue - Information

  // Background & Surface Colors
  static const Color background = Color(0xFFF9FAFB);   // Light Gray - Clean, modern
  static const Color surface = Color(0xFFFFFFFF);      // Pure White - Cards, containers
  static const Color surfaceVariant = Color(0xFFF3F4F6); // Subtle Gray - Alternative surfaces

  // Text Colors - High Contrast & Readable
  static const Color textPrimary = Color(0xFF111827);  // Almost Black - Main text
  static const Color textSecondary = Color(0xFF6B7280); // Medium Gray - Secondary text
  static const Color textTertiary = Color(0xFF9CA3AF); // Light Gray - Placeholder, disabled
  static const Color textLight = Color(0xFFFFFFFF);    // Pure White - On dark backgrounds

  // Interactive Colors
  static const Color primaryLight = Color(0xFFD1FAE5); // Light Green - Hover, pressed states
  static const Color accentLight = Color(0xFFFFE5D9);  // Light Orange - Accent backgrounds

  // Gradient Colors - Modern & Eye-catching
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00A878), Color(0xFF00C896)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border & Divider Colors
  static const Color border = Color(0xFFE5E7EB);       // Subtle border
  static const Color divider = Color(0xFFF3F4F6);      // Light divider

  // Shadow Colors
  static Color shadow = const Color(0xFF111827).withOpacity(0.08);
  static Color shadowStrong = const Color(0xFF111827).withOpacity(0.15);

  // Category/Tag Colors - Diverse & Recognizable
  static const Color categoryFood = Color(0xFFFF6B35);      // Orange
  static const Color categoryGrocery = Color(0xFF10B981);   // Green
  static const Color categoryBeverages = Color(0xFF8B5CF6); // Purple
  static const Color categoryHealthy = Color(0xFF00A878);   // Teal
  static const Color categoryDessert = Color(0xFFEC4899);   // Pink
  static const Color categoryFastFood = Color(0xFFF59E0B);  // Amber
}
/// 🧱 Global theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.danger),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        titleLarge: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
