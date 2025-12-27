import 'package:flutter/material.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/common/animations/scale_button.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';

/// A compact, high-density tile for data lists (Bookings, Expenses).
/// Expandable to show actions, saving screen real estate.
class DataListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? statusPill;
  final List<Widget> compactRows; // Shown when collapsed (limit 1-2)
  final List<Widget> expandedRows; // Shown when expanded
  final List<Widget>? actions; // Shown at bottom when expanded
  final VoidCallback? onTap;

  const DataListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.statusPill,
    this.compactRows = const [],
    this.expandedRows = const [],
    this.actions,
    this.onTap,
  });

  @override
  State<DataListTile> createState() => _DataListTileState();
}

class _DataListTileState extends State<DataListTile> {
  bool _isExpanded = false;

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: _toggle,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppLayout.gapM), // Compact padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: AppTypography.headlineSmall),
                      if (widget.subtitle != null)
                        Text(widget.subtitle!,
                            style: AppTypography.bodySmall
                                .copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                if (widget.statusPill != null) widget.statusPill!,
              ],
            ),

            const SizedBox(height: AppLayout.gapS),

            // Compact Info (Always Visible)
            ...widget.compactRows.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: e,
                )),

            // Expanded Section
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: AppLayout.gapXs),
                  ...widget.expandedRows.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: e,
                      )),
                  if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                    const SizedBox(height: AppLayout.gapM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: widget.actions!,
                    )
                  ]
                ],
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper for key-value rows in the tile
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text('$label: ', style: AppTypography.bodySmall),
        Expanded(
          child: Text(value,
              style:
                  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
