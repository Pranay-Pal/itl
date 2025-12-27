import 'package:flutter/material.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/common/widgets/design_system/glass_container.dart';

/// A compact filter bar that sits at the top of lists.
/// Shows "Active Filters" as chips, and a button to open the full modal.
class FilterIsland extends StatelessWidget {
  final VoidCallback onFilterTap;
  final VoidCallback onClearTap;
  final List<String> activeFilters; // ["Month: Jan", "Status: Paid"]

  const FilterIsland({
    super.key,
    required this.onFilterTap,
    required this.onClearTap,
    required this.activeFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppLayout.gapL),
        children: [
          // Filter Button
          Center(
            child: GestureDetector(
              onTap: onFilterTap,
              child: GlassContainer(
                isNeon: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: BorderRadius.circular(30),
                child: Row(
                  children: const [
                    Icon(Icons.filter_list, size: 18),
                    SizedBox(width: 8),
                    Text('Filters',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          if (activeFilters.isNotEmpty) ...[
            const SizedBox(width: AppLayout.gapM),
            // Clear All (Text Button)
            Center(
              child: IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onClearTap,
                tooltip: 'Reset',
              ),
            ),
            const SizedBox(width: AppLayout.gapS),
          ],

          // Active Chips
          ...activeFilters.map((filter) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(filter, style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
