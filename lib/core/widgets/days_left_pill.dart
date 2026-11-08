import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// "12 days left" / "Due today" / "3 days overdue" (red when [overdue]) /
/// "Deadline passed". [days] is whole days until the deadline, negative
/// once it has passed. Used for projects and tasks.
class DaysLeftPill extends StatelessWidget {
  const DaysLeftPill({super.key, required this.days, required this.overdue});

  final int days;
  final bool overdue;

  String get _label {
    if (days < 0) {
      return overdue
          ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
          : 'Deadline passed';
    }
    if (days == 0) return 'Due today';
    return '$days ${days == 1 ? 'day' : 'days'} left';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = overdue
        ? (
            theme.colorScheme.error.withValues(alpha: 0.12),
            theme.colorScheme.error,
          )
        : (theme.appColors.chipBackground, theme.appColors.chipText);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
