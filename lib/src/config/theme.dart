import 'package:flutter/material.dart';

// WhatsApp Official/Common Colors
class AppColors {
  // Light Theme
  static const lightPrimary = Color(0xFF075E54); // Teal Green
  static const lightSecondary = Color(0xFF128C7E); // Light Teal
  static const lightBackground = Color(0xFFECE5DD); // Beige / Doodle BG color
  static const lightBubbleSent = Color(0xFFDCF8C6); // Pale Green
  static const lightBubbleReceived = Color(0xFFFFFFFF); // White

  // Dark Theme
  static const darkPrimary = Color(0xFF1F2C34); // Dark Grey/Teal
  static const darkSecondary = Color(0xFF005C4B); // Darker Teal
  static const darkBackground = Color(0xFF0B141A); // Very Dark Blue/Black
  static const darkBubbleSent = Color(0xFF005C4B); // Dark Teal
  static const darkBubbleReceived = Color(0xFF1F2C34); // Dark Grey
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.lightPrimary,
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightPrimary,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF25D366), // WhatsApp Green FAB
    foregroundColor: Colors.white,
  ),
  // Default font for the app
  // fontFamily: GoogleFonts.inter().fontFamily,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: AppColors.lightSecondary,
    brightness: Brightness.light,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.darkPrimary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkPrimary,
    foregroundColor: Colors.grey, // Headers often greyish in dark mode
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor:
        Color(0xFF00A884), // Slightly different green for dark mode
    foregroundColor: Colors.white,
  ),
  // fontFamily: GoogleFonts.inter().fontFamily, // Removed to avoid runtime fetch errors
  colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
    secondary: AppColors.darkSecondary,
    surface: AppColors.darkBackground,
    brightness: Brightness.dark,
  ),
);
