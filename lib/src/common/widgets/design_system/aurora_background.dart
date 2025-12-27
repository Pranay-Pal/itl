import 'package:flutter/material.dart';

import 'package:itl/src/config/app_theme_extension.dart';

/// A subtle, animated gradient background with moving "Aurora" blobs.
/// Uses colors from [AppThemeExtension].
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppThemeExtension>()?.auroraColors ??
            const [Colors.blue, Colors.purple, Colors.cyan];

    return Stack(
      children: [
        // Base Background
        const Positioned.fill(child: ColoredBox(color: Colors.transparent)),

        // Blob 1 (Top Left)
        Positioned(
          top: -100,
          left: -100,
          child: _buildBlob(colors[0]),
        ),

        // Blob 2 (Center Right)
        Positioned(
          top: 200,
          right: -50,
          child: _buildBlob(colors[1]),
        ),

        // Blob 3 (Bottom Left)
        Positioned(
          bottom: -100,
          left: -50,
          child: _buildBlob(colors.length > 2 ? colors[2] : colors[0]),
        ),

        // Child Content
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _buildBlob(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }
}
