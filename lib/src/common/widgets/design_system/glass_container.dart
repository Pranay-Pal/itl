import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_theme_extension.dart';

/// A container that applies a Glassmorphism effect (Blur + Translucency).
/// Can also apply a "Neon" glow for high-emphasis items.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isNeon; // If true, adds the Glow Shadow
  final bool hasBorder; // If false, removes the border
  final Color? color; // Override background color
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.isNeon = false,
    this.hasBorder = true,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>()!;
    final radius = borderRadius ?? BorderRadius.circular(AppLayout.radiusL);

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? ext.glassColor,
        borderRadius: radius,
        border: hasBorder
            ? Border.all(
                color: isNeon
                    ? theme.primaryColor.withValues(alpha: 0.5)
                    : ext.glassBorder,
                width: isNeon ? 1.5 : 1.0,
              )
            : null,
        boxShadow: [
          if (isNeon) ext.glowShadow else ext.softShadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: ext.glassBlur, sigmaY: ext.glassBlur),
          child: Padding(
            padding: padding ?? AppLayout.cardPadding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
