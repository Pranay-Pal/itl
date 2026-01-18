import 'package:flutter/material.dart';

/// The ITL "Cyber-Glass" Color Palette
///
/// This file defines the raw colors and semantic mappings for the
/// "Neon Night" (Dark) and "Frosted Day" (Light) themes.
class AppPalette {
  const AppPalette._();

  // --- Base Palette (Raw Colors) ---

  // Cyans & Blues (The Core DNA)
  static const Color neonCyan = Color(0xFF00D4FF); // High energy accent
  static const Color electricBlue = Color(0xFF4361EE); // Primary Brand
  static const Color oceanBlue = Color(0xFF0057FF); // Vibrant primary (Light)
  static const Color deepVoid = Color(0xFF050B14); // Darkest background
  static const Color navySurface = Color(0xFF0F1C2E); // Dark surface
  static const Color iceBlue = Color(0xFFF2F6F9); // Lightest background
  static const Color coolWhite = Color(0xFFFFFFFF); // Light surface

  // Accents
  static const Color cyberPurple = Color(0xFF7209B7);
  static const Color primaryPurple = Color(0xFF7209B7); // For button background
  static const Color successGreen = Color(0xFF00F5D4); // Neon Green
  static const Color dangerRed = Color(0xFFFF2E63); // Neon Red
  static const Color warningOrange = Color(0xFFFF9F1C);

  // Neutrals (Glass Tints)
  static const Color glassWhite = Colors.white;
  static const Color glassBlack = Colors.black;

  // --- Semantic Colors (Dark Mode) ---
  static const Color darkBackground = deepVoid;
  static const Color darkSurface = navySurface;
  static const Color darkPrimary = neonCyan;
  static const Color darkSecondary = electricBlue;
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // --- Semantic Colors (Light Mode) ---
  static const Color lightBackground = iceBlue;
  static const Color lightSurface = coolWhite;
  static const Color lightPrimary = oceanBlue;
  static const Color lightSecondary = Color(0xFF00A8E8); // Sky Blue
  static const Color lightTextPrimary = Color(0xFF1E293B); // Slate 800
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
}
