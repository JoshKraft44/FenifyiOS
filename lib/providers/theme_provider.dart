import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Provider that manages theme state across app using ChangeNotifier
/// Supports both light and dark themes with persistent storage using SharedPreferences
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Default to dark mode for modern look
  static const String _themeKey = 'isDarkMode';

  /// Initialize the theme provider and load saved preference
  ThemeProvider() {
    _loadThemePreference();
  }

  /// Returns current theme mode (dark or light)
  bool get isDarkMode => _isDarkMode;

  /// Returns the appropriate ThemeData based on current theme mode
  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

  /// Dark theme configuration with black background and blue accents
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: AppColors.columbiaBlue,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.columbiaBlue,
      secondary: AppColors.lightBlue,
      surface: Color(0xFF1a1a1a),
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.columbiaBlue,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white.withOpacity(0.6),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white),
    ),
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.seasalt,
    primaryColor: AppColors.deepNavy,
    colorScheme: const ColorScheme.light(
      primary: AppColors.deepNavy,
      secondary: AppColors.columbiaBlue,
      surface: Colors.white,
      onSurface: AppColors.deepNavy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.seasalt,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.deepNavy),
      titleTextStyle: TextStyle(
        color: AppColors.deepNavy,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightBlue.withOpacity(0.3)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.columbiaBlue,
        foregroundColor: AppColors.deepNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.columbiaBlue,
      unselectedItemColor: AppColors.cadetGray,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.deepNavy),
      bodyMedium: TextStyle(color: AppColors.deepNavy),
      titleLarge: TextStyle(color: AppColors.deepNavy),
      titleMedium: TextStyle(color: AppColors.deepNavy),
      titleSmall: TextStyle(color: AppColors.deepNavy),
    ),
  );

  /// Toggles between dark and light theme modes
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference();
    notifyListeners();
  }

  /// Sets theme mode explicitly (true for dark, false for light)
  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    _saveThemePreference();
    notifyListeners();
  }

  /// Loads the saved theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true; // Default to dark
    notifyListeners();
  }

  /// Saves the current theme preference to SharedPreferences
  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }
}

/// Extension methods on BuildContext for easy theme access in widgets
extension ThemeExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  /// Background color that adapts to theme 
  Color get backgroundColor => isDarkMode ? Colors.black : AppColors.seasalt;
  
  /// Surface color for cards and containers (
  Color get surfaceColor => isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;
  
  /// Primary text color 
  Color get primaryTextColor => isDarkMode ? Colors.white : AppColors.deepNavy;
  
  /// Secondary/muted text color
  Color get secondaryTextColor => isDarkMode ? Colors.white.withOpacity(0.7) : AppColors.cadetGray;
  
  /// Border color for outlines and dividers
  Color get borderColor => isDarkMode ? Colors.white.withOpacity(0.1) : AppColors.lightBlue.withOpacity(0.3);
  
  /// Icon color
  Color get iconColor => isDarkMode ? Colors.white : AppColors.deepNavy;
  
  /// Accent color - consistent across themes
  Color get accentColor => AppColors.columbiaBlue;
}