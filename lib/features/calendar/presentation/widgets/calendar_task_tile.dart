import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../tasks/presentation/widgets/task_status_badge.dart';
import '../../application/calendar_providers.dart';

/// One row of "Tasks on selected day" (mock 04): a status icon tile,
/// the title, "Project • Assignee", and the status pill (or Overdue).
class CalendarTaskTile extends StatelessWidget {
  const CalendarTaskTile({
    super.key,
    required this.item,
    required this.subtitle,
    required this.overdue,
    required this.onTap,
  });

  final CalendarTask item;
  final String subtitle;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final task = item.task;
    final (tileBg, tileFg) = overdue
        ? (colors.error.withValues(alpha: 0.12), colors.error)
        : taskStatusColors(theme.appColors, task.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  overdue
                      ? Icons.warning_amber_rounded
                      : taskStatusIcon(task.status),
                  size: 20,
                  color: tileFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              overdue
                  ? const OverdueBadge()
                  : TaskStatusBadge(status: task.status),
            ],
          ),
        ),
      ),
    );
  }
}
