import 'package:flutter/material.dart';

import '../../data/leave_balance.dart';
import '../../data/working_days.dart';

/// Used / Remaining / Pending (mock 02). Remaining is highlighted with a
/// top accent bar, as in the mock.
class LeaveStatTiles extends StatelessWidget {
  const LeaveStatTiles({super.key, required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(label: 'Used', days: balance.used),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            label: 'Remaining',
            days: balance.remaining,
            highlight: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(label: 'Pending', days: balance.pending),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.days,
    this.highlight = false,
  });

  final String label;
  final num days;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: '$label: ${formatDays(days)} ${days == 1 ? 'day' : 'days'}',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 3,
              color: highlight ? theme.colorScheme.primary : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              child: Column(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDays(days),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    days == 1 ? 'day' : 'days',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
