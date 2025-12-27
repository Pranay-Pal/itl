import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A wrapper that animates a list of children with a staggered slide-up and fade-in effect.
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final double delayOffset; // Delay in ms per item
  final Duration duration;

  const StaggeredList({
    super.key,
    required this.children,
    this.delayOffset = 50.0,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return child
            .animate(delay: (delayOffset * index).ms)
            .fadeIn(duration: duration, curve: Curves.easeOut)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: duration,
              curve: Curves.easeOut,
            );
      }).toList(),
    );
  }
}
