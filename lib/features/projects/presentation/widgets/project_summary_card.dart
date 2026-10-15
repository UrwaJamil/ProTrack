import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../application/project_filters.dart';
import '../../data/project.dart';
import 'project_progress_bar.dart';

/// Description, date range with a days-left pill, and progress.
class ProjectSummaryCard extends StatelessWidget {
  const ProjectSummaryCard({
    super.key,
    required this.project,
    required this.progress,
    required this.today,
  });

  final Project project;
  final int progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = isOverdue(project, today: today, progress: progress);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              project.description.isEmpty
                  ? 'No description.'
                  : project.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: project.description.isEmpty
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.date_range_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatDateRange(project.startDate, project.deadline),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!project.isArchived)
                  _DaysPill(
                    days: daysRemaining(project.deadline, today),
                    overdue: overdue,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ProjectProgressBar(progress: progress, overdue: overdue),
          ],
        ),
      ),
    );
  }
}

class _DaysPill extends StatelessWidget {
  const _DaysPill({required this.days, required this.overdue});

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
