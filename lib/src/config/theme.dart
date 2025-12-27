import 'package:flutter/material.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/app_theme_extension.dart';
import 'package:itl/src/config/typography.dart';

class AppTheme {
  const AppTheme._();

  // --- Light Theme ---
  static ThemeData get light => _baseTheme(
        brightness: Brightness.light,
        background: AppPalette.lightBackground,
        surface: AppPalette.lightSurface,
        primary: AppPalette.lightPrimary,
        secondary: AppPalette.lightSecondary,
        textPrimary: AppPalette.lightTextPrimary,
        textSecondary: AppPalette.lightTextSecondary,
        extension: AppThemeExtension.light,
      );

  // --- Dark Theme ---
  static ThemeData get dark => _baseTheme(
        brightness: Brightness.dark,
        background: AppPalette.darkBackground,
        surface: AppPalette.darkSurface,
        primary: AppPalette.darkPrimary,
        secondary: AppPalette.darkSecondary,
        textPrimary: AppPalette.darkTextPrimary,
        textSecondary: AppPalette.darkTextSecondary,
        extension: AppThemeExtension.dark,
      );

  static ThemeData _baseTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color textPrimary,
    required Color textSecondary,
    required AppThemeExtension extension,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: AppPalette.dangerRed,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: textPrimary),
        displaySmall: AppTypography.displaySmall.copyWith(color: textPrimary),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: textPrimary),
        headlineMedium:
            AppTypography.headlineMedium.copyWith(color: textPrimary),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: textPrimary),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: textPrimary),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: textPrimary),
        bodySmall: AppTypography.bodySmall.copyWith(color: textSecondary),
        labelLarge: AppTypography.labelLarge.copyWith(
            color: brightness == Brightness.dark ? Colors.white : Colors.white),
        labelMedium: AppTypography.labelMedium.copyWith(color: textSecondary),
        labelSmall: AppTypography.labelSmall.copyWith(color: textSecondary),
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            AppTypography.headlineMedium.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: primary),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppLayout.radiusL)),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extension.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppLayout.gapL, vertical: AppLayout.gapM),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusM),
          borderSide: BorderSide(
              color: brightness == Brightness.light
                  ? AppPalette.coolWhite.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusM),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: textSecondary),
        labelStyle: AppTypography.bodyMedium.copyWith(color: textSecondary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle:
              AppTypography.labelLarge, // Ensuring bold tech font for buttons
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusRound),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.gapXl, vertical: AppLayout.gapM),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),

      iconTheme: IconThemeData(color: textPrimary, size: AppLayout.iconSizeM),
      dividerTheme: DividerThemeData(
          color: textSecondary.withValues(alpha: 0.2), thickness: 1),

      // Extensions
      extensions: [extension],
    );
  }
}
