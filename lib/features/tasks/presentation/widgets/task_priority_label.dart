import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/task_priority.dart';

/// "⚑ High" in error red, "⚑ Medium" in amber, "⚑ Low" muted — plain text
/// rather than another pill, so it doesn't compete with the status badge.
class TaskPriorityLabel extends StatelessWidget {
  const TaskPriorityLabel({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (priority) {
      TaskPriority.high => theme.colorScheme.error,
      TaskPriority.medium => theme.appColors.warning,
      TaskPriority.low => theme.colorScheme.onSurfaceVariant,
    };
    return Semantics(
      label: '${priority.label} priority',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
