import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The rounded 26px pill behind every status badge (project and task).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.children,
    this.background,
    this.border,
  });

  final List<Widget> children;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// "⚠ Overdue" — red outline rather than a red fill, which would drop the
/// small red text below 4.5:1 in light mode. Shared by projects and tasks.
class OverdueBadge extends StatelessWidget {
  const OverdueBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return StatusPill(
      border: error.withValues(alpha: 0.45),
      children: [
        Icon(Icons.warning_amber_rounded, size: 15, color: error),
        const SizedBox(width: 4),
        Text(
          'Overdue',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: error,
          ),
        ),
      ],
    );
  }
}

/// The small "PRJ-7F3K" / "TSK-7F3K" / count style pill.
class LabelPill extends StatelessWidget {
  const LabelPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.appColors.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.appColors.chipText,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
