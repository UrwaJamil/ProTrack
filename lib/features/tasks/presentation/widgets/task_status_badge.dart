import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/task_status.dart';

/// Icon for each status, so badges don't rely on color alone.
IconData taskStatusIcon(TaskStatus status) => switch (status) {
  TaskStatus.todo => Icons.radio_button_unchecked,
  TaskStatus.inProgress => Icons.timelapse,
  TaskStatus.onHold => Icons.pause_circle_outline,
  TaskStatus.blocked => Icons.block,
  TaskStatus.completed => Icons.check_circle_outline,
};

/// (background, foreground) for a status, from [AppColors]' `status*`
/// tokens.
(Color, Color) taskStatusColors(AppColors c, TaskStatus status) =>
    switch (status) {
      TaskStatus.todo => (c.statusToDoBackground, c.statusToDoText),
      TaskStatus.inProgress => (
        c.statusInProgressBackground,
        c.statusInProgressText,
      ),
      TaskStatus.onHold => (c.statusOnHoldBackground, c.statusOnHoldText),
      TaskStatus.blocked => (c.statusBlockedBackground, c.statusBlockedText),
      TaskStatus.completed => (
        c.statusCompletedBackground,
        c.statusCompletedText,
      ),
    };

/// "○ Not Started", "◔ In Progress", "⏸ On Hold", "✓ Completed" …
class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = taskStatusColors(theme.appColors, status);
    return StatusPill(
      background: bg,
      children: [
        Icon(taskStatusIcon(status), size: 14, color: fg),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
