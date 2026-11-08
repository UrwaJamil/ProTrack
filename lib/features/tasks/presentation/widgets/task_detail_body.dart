import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/status_pill.dart';
import '../../../projects/application/projects_providers.dart';
import '../../application/task_filters.dart';
import '../../application/task_permissions.dart';
import '../../data/task.dart';
import '../../data/task_repository.dart';
import '../../data/task_status.dart';
import 'status_selector.dart';
import 'subtask_checklist.dart';
import 'task_info_card.dart';
import 'task_priority_label.dart';
import 'task_status_badge.dart';

/// Everything below the app bar on Task Detail: badges and title, the
/// info card (required work, deadline, assignees), status (FR-3.6) and
/// the subtask checklist (FR-3.5).
class TaskDetailBody extends ConsumerStatefulWidget {
  const TaskDetailBody({
    super.key,
    required this.task,
    required this.permissions,
  });

  final Task task;
  final TaskPermissions permissions;

  @override
  ConsumerState<TaskDetailBody> createState() => _TaskDetailBodyState();
}

class _TaskDetailBodyState extends ConsumerState<TaskDetailBody> {
  bool _saving = false;

  Future<void> _write(Future<void> Function(TaskRepository repo) action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await action(ref.read(taskRepositoryProvider));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the change. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setStatus(TaskStatus status) => _write(
    (repo) => repo.updateStatus(widget.task.projectId, widget.task.id, status),
  );

  void _toggle(int index, bool done) => _write(
    (repo) => repo.setSubtaskDone(
      widget.task.projectId,
      widget.task.id,
      index: index,
      expectedTitle: widget.task.subtasks[index].title,
      done: done,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final permissions = widget.permissions;
    final project = permissions.project;
    final today = ref.watch(todayProvider);
    final overdue = isTaskOverdue(task, today: today);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                      LabelPill(label: task.shortId),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TaskPriorityLabel(priority: task.priority),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${project.name} · ${project.shortId}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (project.isArchived) ...[
              const SizedBox(height: 16),
              const _ArchivedNotice(),
            ],
            const SizedBox(height: 16),
            TaskInfoCard(task: task, overdue: overdue),
            const SizedBox(height: 24),
            _SectionTitle(
              'Status',
              trailing: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            if (permissions.canUpdateStatus)
              StatusSelector(
                value: task.status,
                onChanged: _saving ? null : _setStatus,
              )
            else
              _ReadOnlyStatus(status: task.status),
            const SizedBox(height: 24),
            _SectionTitle(
              'Subtasks',
              trailing: task.subtasks.isEmpty
                  ? null
                  : LabelPill(
                      label: '${task.subtasksDone}/${task.subtasks.length}',
                    ),
            ),
            const SizedBox(height: 8),
            if (task.subtasks.isEmpty)
              Text(
                'No subtasks — the required work above is the whole task.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              SubtaskChecklist(
                subtasks: task.subtasks,
                onToggle: permissions.canToggleSubtasks && !_saving
                    ? _toggle
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _ReadOnlyStatus extends StatelessWidget {
  const _ReadOnlyStatus({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TaskStatusBadge(status: status),
        Text(
          'Only the assignee or an Admin can change the status.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ArchivedNotice extends StatelessWidget {
  const _ArchivedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('This project is archived'),
        subtitle: Text(
          'Tasks are read-only until an Admin restores it.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
