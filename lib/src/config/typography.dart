import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The ITL Typography System
///
/// Uses [Outfit] for Headings (Tech/Geometric) and
/// [Manrope] for Body (Readable/Modern digits).
class AppTypography {
  const AppTypography._();

  // --- Text Styles (To be used in ThemeData) ---

  // Display (Large Headings)
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -1.0,
      );

  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      );

  static TextStyle get displaySmall => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      );

  // Headlines (Section Titles)
  static TextStyle get headlineLarge => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineMedium => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get headlineSmall => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  // Body (Content)
  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.15,
      );

  static TextStyle get bodyMedium => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.25,
      );

  static TextStyle get bodySmall => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.4,
      );

  // Labels (Buttons, Chips)
  static TextStyle get labelLarge => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.25, // Caps usually need spacing
      );

  static TextStyle get labelMedium => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
      );

  static TextStyle get labelSmall => GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      );
}
