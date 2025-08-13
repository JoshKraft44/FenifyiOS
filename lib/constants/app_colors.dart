import 'dart:ui';

/// Centralized color palette
/// Provides consistent theming across all UI components.
class AppColors {
  // Primary color palette
  static const Color deepNavy = Color(0xFF1a1a2e);
  static const Color cadetGray = Color(0xFF4a5568);
  static const Color lightBlue = Color(0xFF94C5CC);
  static const Color columbiaBlue = Color(0xFFB4D2E7);
  static const Color seasalt = Color(0xFFF7FAFC);
  
  // Status colors
  static const Color successGreen = Color(0xFF7FB069);
  static const Color warningOrange = Color(0xFFE07A5F);
  static const Color errorRed = Color(0xFFD32F2F);
  
  // Utility colors (common Flutter colors for reference)
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  
  // Prevent instantiation
  AppColors._();
}