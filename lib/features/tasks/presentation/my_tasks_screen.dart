import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../application/task_filters.dart';
import '../application/tasks_providers.dart';
import 'task_paths.dart';
import 'widgets/task_card.dart';

/// The Member's "My Tasks" tab (FR-3.4): every task assigned to them
/// across their projects, open ones first by deadline (overdue on top),
/// completed ones below.
class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(myTasksProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(
            message: "We couldn't load your tasks.",
            onRetry: () {
              ref.invalidate(assignedTasksProvider);
              ref.invalidate(myProjectsProvider);
            },
          ),
          data: (items) =>
              items.isEmpty ? const _NoTasks() : _TaskList(items: items),
        );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.items});

  final List<AssignedTask> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final open = items.where((i) => !i.task.isCompleted).toList();
    final done = items.where((i) => i.task.isCompleted).toList();
    final overdue = open.where((i) => isTaskOverdue(i.task, today: today));
    final profiles =
        ref
            .watch(
              userProfilesProvider(
                profilesKey(items.expand((i) => i.task.assignedTo)),
              ),
            )
            .value ??
        const <String, AppUser>{};

    Widget card(AssignedTask item) => TaskCard(
      task: item.task,
      projectName: item.project.name,
      overdue: isTaskOverdue(item.task, today: today),
      assignees: [
        for (final id in item.task.assignedTo)
          (uid: id, name: profiles[id]?.name ?? ''),
      ],
      onOpen: () => context.push(
        taskDetailPath(item.project.id, item.task.id, adminView: false),
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Header(open: open.length, overdue: overdue.length),
            const SizedBox(height: 16),
            if (open.isEmpty)
              const _AllDone()
            else
              for (final (i, item) in open.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                card(item),
              ],
            if (done.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle('Completed', count: done.length),
              const SizedBox(height: 8),
              for (final (i, item) in done.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                card(item),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.open, required this.overdue});

  final int open;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = [
      '$open open',
      if (overdue > 0) '$overdue overdue',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Tasks',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: overdue > 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: overdue > 0 ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        LabelPill(label: '$count'),
      ],
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          Icons.celebration_outlined,
          color: theme.appColors.success,
        ),
        title: const Text('All caught up'),
        subtitle: Text(
          'Every task assigned to you is completed.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _NoTasks extends StatelessWidget {
  const _NoTasks();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.checklist_outlined,
      title: 'No tasks yet',
      message:
          'Tasks an Admin assigns to you show up here, across all your '
          'projects.',
    );
  }
}
