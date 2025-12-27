import 'package:flutter/material.dart';

/// The ITL Layout System
///
/// Defines the centralized constants for spacing, radii, and grid sizing.
/// Adheres to an 4pt/8pt soft grid.
class AppLayout {
  const AppLayout._();

  // --- Spacing (Grid) ---
  static const double gapXs = 4.0;
  static const double gapS = 8.0;
  static const double gapM = 12.0; // "Compact" standard
  static const double gapL = 16.0; // "Airy" standard
  static const double gapXl = 24.0;
  static const double gapSection = 32.0;
  static const double gapPage = 20.0; // Standard page margin

  // --- Border Radii ---
  static const double radiusXs = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0; // Standard widgets
  static const double radiusL = 16.0; // Cards
  static const double radiusXl = 24.0; // Dialogs / High emphasis
  static const double radiusRound = 100.0; // Pills

  // --- Sizing ---
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 20.0;
  static const double iconSizeL = 24.0;

  static const double buttonHeight = 48.0;
  static const double buttonHeightCompact = 36.0;
  static const double inputHeight = 48.0;
  static const double inputHeightCompact = 40.0;

  // --- Data Density ---
  static const EdgeInsets cardPadding = EdgeInsets.all(12.0);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(8.0);
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: gapPage, vertical: gapM);
}
