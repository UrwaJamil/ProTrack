import 'package:flutter/material.dart';

import '../../../projects/data/project.dart';
import '../../data/task.dart';
import 'task_status_badge.dart';

/// Top of the Comments / History and Need Help screens: "TASK TSK-7F3K",
/// title, status badge, and the project line.
class TaskActivityHeader extends StatelessWidget {
  const TaskActivityHeader({
    super.key,
    required this.task,
    required this.project,
    this.caption,
  });

  final Task task;
  final Project project;

  /// Replaces the "TASK TSK-…" caption (e.g. "RELATED TASK").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                caption ?? 'TASK ${task.shortId}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TaskStatusBadge(status: task.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          task.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${project.name} · ${project.shortId}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
