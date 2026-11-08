import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/days_left_pill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../../projects/application/project_filters.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/task.dart';

/// Required work, deadline (with days left / overdue) and assignees
/// (FR-3.4).
class TaskInfoCard extends ConsumerWidget {
  const TaskInfoCard({super.key, required this.task, required this.overdue});

  final Task task;
  final bool overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Required work', style: muted),
            const SizedBox(height: 6),
            Text(
              task.description.isEmpty ? 'No details given.' : task.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: task.description.isEmpty
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
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
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: overdue ? colors.error : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Due ${formatDate(task.deadline)}',
                      style: muted?.copyWith(
                        color: overdue ? colors.error : null,
                        fontWeight: overdue ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
                if (!task.isCompleted)
                  DaysLeftPill(
                    days: daysRemaining(task.deadline, today),
                    overdue: overdue,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Assigned to', style: muted),
            const SizedBox(height: 8),
            _Assignees(task: task),
          ],
        ),
      ),
    );
  }
}

class _Assignees extends ConsumerWidget {
  const _Assignees({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (task.assignedTo.isEmpty) {
      return Text(
        'Unassigned',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final profiles =
        ref.watch(userProfilesProvider(profilesKey(task.assignedTo))).value ??
        const <String, AppUser>{};
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        for (final id in task.assignedTo)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(uid: id, name: profiles[id]?.name ?? '', size: 28),
              const SizedBox(width: 8),
              Text(
                profiles[id]?.name ?? 'Unknown user',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
