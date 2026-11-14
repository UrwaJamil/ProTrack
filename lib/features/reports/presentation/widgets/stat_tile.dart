import 'package:flutter/material.dart';

/// One Analytics tile (mock 03): label top-left, icon top-right, big
/// number below. [valueColor] tints the number (red Overdue, amber
/// Blocked).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(icon, size: 18, color: iconColor ?? muted),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 2×2 grid of [StatTile]s.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});

  /// Exactly four, in reading order.
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    Widget row(int i) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tiles[i]),
          const SizedBox(width: 10),
          Expanded(child: tiles[i + 1]),
        ],
      ),
    );
    return Column(children: [row(0), const SizedBox(height: 10), row(2)]);
  }
}
