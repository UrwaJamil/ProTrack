import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/task.dart';
import 'task_priority_label.dart';
import 'task_status_badge.dart';

/// One task in a list (Project Detail, My Tasks): status (+ Overdue),
/// priority, title, two-line required work, deadline, subtask count and
/// assignee avatars. Overdue follows the project card: the Overdue badge
/// and the deadline in red.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.overdue,
    required this.assignees,
    required this.onOpen,
    this.projectName,
  });

  final Task task;
  final bool overdue;
  final List<({String uid, String name})> assignees;
  final VoidCallback onOpen;

  /// Shown above the title on My Tasks, where tasks come from many
  /// projects.
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TaskStatusBadge(status: task.status),
                        if (overdue) const OverdueBadge(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TaskPriorityLabel(priority: task.priority),
                ],
              ),
              const SizedBox(height: 10),
              if (projectName != null) ...[
                Text(
                  projectName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: colors.onSurfaceVariant,
                ),
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Footer(task: task, overdue: overdue, assignees: assignees),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.task,
    required this.overdue,
    required this.assignees,
  });

  final Task task;
  final bool overdue;
  final List<({String uid, String name})> assignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final dateColor = overdue ? colors.error : colors.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 16, color: dateColor),
        const SizedBox(width: 6),
        Text(
          formatDate(task.deadline),
          style: muted?.copyWith(
            color: dateColor,
            fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (task.subtasks.isNotEmpty) ...[
          const SizedBox(width: 14),
          Icon(Icons.checklist, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '${task.subtasksDone}/${task.subtasks.length}',
            semanticsLabel:
                '${task.subtasksDone} of ${task.subtasks.length} '
                'subtasks done',
            style: muted,
          ),
        ],
        const Spacer(),
        if (assignees.isEmpty)
          Text('Unassigned', style: muted)
        else
          AvatarStack(people: assignees),
      ],
    );
  }
}
