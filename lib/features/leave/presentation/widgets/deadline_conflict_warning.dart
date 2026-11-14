import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../tasks/data/task.dart';

/// "2 tasks are due during this leave" with their titles and dates. A
/// warning only: it never blocks a request or a decision. [whose] is
/// "your" on the request form and the requester's name for approvers.
class DeadlineConflictWarning extends StatelessWidget {
  const DeadlineConflictWarning({
    super.key,
    required this.tasks,
    this.whose = 'your',
    this.maxListed = 3,
  });

  final List<Task> tasks;
  final String whose;
  final int maxListed;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final warning = theme.appColors.warning;
    final n = tasks.length;
    final more = n - maxListed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n of $whose ${n == 1 ? 'task is' : 'tasks are'} due '
                  'during this leave',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final t in tasks.take(maxListed))
                  Text(
                    '• ${t.title} (${formatDate(t.deadline)})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (more > 0)
                  Text(
                    '+ $more more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
