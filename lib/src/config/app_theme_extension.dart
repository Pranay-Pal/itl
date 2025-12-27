import 'package:flutter/material.dart';
import 'package:itl/src/config/app_palette.dart';

/// Custom Theme Extension for "Cyber-Glass" Properties
///
/// Extends [ThemeData] to include properties that don't fit into the
/// standard Material Design (e.g. Glass colors, Glow shadows).
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // Glassmorphism
  final Color glassColor;
  final Color glassBorder;
  final double glassBlur;
  final double glassOpacity;

  // Effects
  final BoxShadow glowShadow;
  final BoxShadow softShadow;

  // Backgrounds
  final List<Color> auroraColors;

  // Sub-Surfaces
  final Color cardColor;
  final Color surfaceSubtle;

  const AppThemeExtension({
    required this.glassColor,
    required this.glassBorder,
    required this.glassBlur,
    required this.glassOpacity,
    required this.glowShadow,
    required this.softShadow,
    required this.auroraColors,
    required this.cardColor,
    required this.surfaceSubtle,
  });

  @override
  AppThemeExtension copyWith({
    Color? glassColor,
    Color? glassBorder,
    double? glassBlur,
    double? glassOpacity,
    BoxShadow? glowShadow,
    BoxShadow? softShadow,
    List<Color>? auroraColors,
    Color? cardColor,
    Color? surfaceSubtle,
  }) {
    return AppThemeExtension(
      glassColor: glassColor ?? this.glassColor,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBlur: glassBlur ?? this.glassBlur,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glowShadow: glowShadow ?? this.glowShadow,
      softShadow: softShadow ?? this.softShadow,
      auroraColors: auroraColors ?? this.auroraColors,
      cardColor: cardColor ?? this.cardColor,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      glassColor: Color.lerp(glassColor, other.glassColor, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBlur: (glassBlur + (other.glassBlur - glassBlur) * t),
      glassOpacity: (glassOpacity + (other.glassOpacity - glassOpacity) * t),
      glowShadow: BoxShadow.lerp(glowShadow, other.glowShadow, t)!,
      softShadow: BoxShadow.lerp(softShadow, other.softShadow, t)!,
      auroraColors: auroraColors, // List lerp is complex, keeping simple
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
    );
  }

  // --- Pre-defined Themes ---

  // Dark "Neon Night"
  static final AppThemeExtension dark = AppThemeExtension(
    glassColor: AppPalette.navySurface.withValues(alpha: 0.6),
    glassBorder: Colors.white.withValues(alpha: 0.1),
    glassBlur: 20,
    glassOpacity: 0.6,
    glowShadow: BoxShadow(
        color: AppPalette.neonCyan.withValues(alpha: 0.3),
        blurRadius: 12,
        spreadRadius: 0),
    softShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 8,
        spreadRadius: 0,
        offset: const Offset(0, 4)),
    auroraColors: [
      AppPalette.neonCyan.withValues(alpha: 0.2), // Cyan Blob
      AppPalette.cyberPurple.withValues(alpha: 0.2), // Purple Blob
      AppPalette.electricBlue.withValues(alpha: 0.15), // Blue Blob
    ],
    cardColor: Color(0xFF142438), // Slightly lighter than background
    surfaceSubtle: Color(0xFF0F1C2E),
  );

  // Light "Frosted Day"
  static final AppThemeExtension light = AppThemeExtension(
    glassColor: AppPalette.coolWhite.withValues(alpha: 0.7),
    glassBorder: Colors.white.withValues(alpha: 0.4),
    glassBlur: 25,
    glassOpacity: 0.7,
    glowShadow: BoxShadow(
        color: AppPalette.oceanBlue.withValues(alpha: 0.15), // Colored shadow
        blurRadius: 12,
        spreadRadius: 0),
    softShadow: BoxShadow(
        color: AppPalette.electricBlue
            .withValues(alpha: 0.08), // Blue tinted shadow
        blurRadius: 10,
        spreadRadius: 0,
        offset: const Offset(0, 4)),
    auroraColors: [
      Color(0xFFE0F2FE), // Pale Blue
      Color(0xFFF3E8FF), // Pale Purple
      Color(0xFFE0F7FA), // Pale Cyan
    ],
    cardColor: Colors.white,
    surfaceSubtle: Color(0xFFF8FAFC),
  );
}
