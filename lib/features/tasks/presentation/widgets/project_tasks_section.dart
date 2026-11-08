import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/status_pill.dart';
import '../../../auth/data/app_user.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../projects/data/project.dart';
import '../../application/task_filters.dart';
import '../../application/task_permissions.dart';
import '../../application/tasks_providers.dart';
import '../../data/task.dart';
import '../task_paths.dart';
import 'task_card.dart';

/// "Tasks (N)" on Project Detail (FR-3.1): every task in the project, with
/// "+ Add task" for its Admins. Everyone in the project sees every task;
/// what they can change is decided on the task's own screen.
class ProjectTasksSection extends ConsumerWidget {
  const ProjectTasksSection({
    super.key,
    required this.project,
    required this.uid,
    required this.adminView,
  });

  final Project project;
  final String uid;
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(projectTasksProvider(project.id));
    final canCreate = TaskPermissions(project, uid).canCreate;
    final count = async.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Tasks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              LabelPill(label: '$count'),
            ],
            const Spacer(),
            if (canCreate)
              TextButton.icon(
                onPressed: () => context.push(newTaskPath(project.id)),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => _MessageCard(
            icon: Icons.cloud_off_outlined,
            message: "We couldn't load the tasks.",
            action: TextButton.icon(
              onPressed: () => ref.invalidate(projectTasksProvider(project.id)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
          data: (tasks) => tasks.isEmpty
              ? _MessageCard(
                  icon: Icons.task_outlined,
                  message: canCreate
                      ? 'No tasks yet. Break the project into tasks and '
                            'assign them to your team.'
                      : 'No tasks yet.',
                )
              : _TaskList(project: project, tasks: tasks, adminView: adminView),
        ),
      ],
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.project,
    required this.tasks,
    required this.adminView,
  });

  final Project project;
  final List<Task> tasks;
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    // Same key as the Team Members section, so it's one shared fetch.
    final profiles =
        ref.watch(userProfilesProvider(profilesKey(project.memberIds))).value ??
        const <String, AppUser>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, task) in tasks.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          TaskCard(
            task: task,
            overdue: isTaskOverdue(task, today: today),
            assignees: [
              for (final id in task.assignedTo)
                (uid: id, name: profiles[id]?.name ?? ''),
            ],
            onOpen: () => context.push(
              taskDetailPath(project.id, task.id, adminView: adminView),
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
