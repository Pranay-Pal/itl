import 'package:flutter/material.dart';
import 'package:itl/src/config/app_palette.dart';

class StatusHelper {
  const StatusHelper._();

  static Color getColor(String? status) {
    if (status == null) return Colors.grey;
    final s = status.toLowerCase();

    // Success / Good / Paid
    if (s.contains('approved') ||
        s.contains('paid') ||
        s.contains('success') ||
        s.contains('receive') ||
        s.contains('complete') ||
        s == '2') {
      return AppPalette.successGreen; // Neon Green
    }

    // Danger / Rejected / Cancelled
    if (s.contains('reject') ||
        s.contains('cancel') ||
        s.contains('fail') ||
        s.contains('drop') ||
        s == '4') {
      return AppPalette.dangerRed; // Neon Red
    }

    // Warning / Pending / Processing
    if (s.contains('pending') ||
        s.contains('process') ||
        s.contains(
            'issue') || // Usually 'issued' is a neutral/good state but often ongoing
        s == '0' ||
        s == '1') {
      return AppPalette.warningOrange;
    }

    // Info / New
    if (s.contains('new') || s.contains('info') || s == '3') {
      return AppPalette.neonCyan;
    }

    return Colors.grey;
  }

  static String getLabel(String? status) {
    return status?.toUpperCase() ?? 'UNKNOWN';
  }
}
