import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../application/project_filters.dart';

/// Horizontally scrolling All / Active / Overdue / Archived chips with live
/// counts; Overdue is drawn in the error color.
class ProjectFilterChips extends StatelessWidget {
  const ProjectFilterChips({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final ProjectFilter selected;
  final Map<ProjectFilter, int> counts;
  final ValueChanged<ProjectFilter> onSelected;

  static const _labels = {
    ProjectFilter.all: 'All',
    ProjectFilter.active: 'Active',
    ProjectFilter.overdue: 'Overdue',
    ProjectFilter.archived: 'Archived',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ProjectFilter.values) ...[
            _Chip(
              label: _labels[filter]!,
              count: counts[filter] ?? 0,
              selected: filter == selected,
              danger: filter == ProjectFilter.overdue,
              onTap: () => onSelected(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.appColors;
    final (bg, fg, border, countBg, countFg) = selected
        ? (
            colors.primary,
            colors.onPrimary,
            colors.primary,
            colors.onPrimary.withValues(alpha: 0.18),
            colors.onPrimary,
          )
        : danger
        ? (
            colors.surface,
            colors.error,
            colors.error.withValues(alpha: 0.45),
            colors.error.withValues(alpha: 0.12),
            colors.error,
          )
        : (
            colors.surface,
            colors.onSurface,
            colors.outline,
            appColors.progressTrack,
            colors.onSurfaceVariant,
          );
    final radius = BorderRadius.circular(999);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: countBg,
                    borderRadius: radius,
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: countFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
