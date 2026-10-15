import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

enum ProjectBadgeKind { active, overdue, archived }

/// "● Active", "⚠ Overdue" (red outline — a red fill would drop the small
/// red text below 4.5:1 in light mode) or "Archived".
class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({super.key, required this.kind});

  final ProjectBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.appColors;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return switch (kind) {
      ProjectBadgeKind.active => _Pill(
        background: appColors.success.withValues(alpha: 0.12),
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: appColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('Active', style: style?.copyWith(color: colors.onSurface)),
        ],
      ),
      ProjectBadgeKind.overdue => _Pill(
        border: colors.error.withValues(alpha: 0.45),
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: colors.error),
          const SizedBox(width: 4),
          Text('Overdue', style: style?.copyWith(color: colors.error)),
        ],
      ),
      ProjectBadgeKind.archived => _Pill(
        background: appColors.statusToDoBackground,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 14,
            color: appColors.statusToDoText,
          ),
          const SizedBox(width: 5),
          Text(
            'Archived',
            style: style?.copyWith(color: appColors.statusToDoText),
          ),
        ],
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children, this.background, this.border});

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

/// The small "PRJ-7F3K" / "Admin View" style pill.
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
