import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/task_permissions.dart';
import '../application/tasks_providers.dart';
import 'widgets/need_help_form.dart';

/// Need Help (Phase 4, mock 02), on both dashboards
/// (`…/tasks/:taskId/help`), opened from Comments / History. Sending
/// sets the task to Blocked with a help note tagging the chosen helper.
/// Only the assignee or a project Admin may ask, while the task isn't
/// completed and the project is active.
class NeedHelpScreen extends ConsumerWidget {
  const NeedHelpScreen({
    super.key,
    required this.projectId,
    required this.taskId,
  });

  final String projectId;
  final String taskId;

  TaskKey get _key => (projectId: projectId, taskId: taskId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final projectAsync = ref.watch(projectProvider(projectId));
    final taskAsync = ref.watch(taskProvider(_key));
    final project = projectAsync.value;
    final task = taskAsync.value;

    final Widget body;
    if (projectAsync.hasError || taskAsync.hasError) {
      body = ErrorState(
        message:
            "We couldn't load this task. You may no longer have access "
            'to it.',
        onRetry: () {
          ref.invalidate(projectProvider(projectId));
          ref.invalidate(taskProvider(_key));
        },
      );
    } else if (!projectAsync.hasValue || !taskAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (project == null || task == null) {
      body = const EmptyState(
        icon: Icons.search_off,
        title: 'Task not found',
        message: 'It may have been deleted.',
      );
    } else if (!TaskPermissions(project, uid, task).canUpdateStatus ||
        task.isCompleted) {
      body = const EmptyState(
        icon: Icons.lock_outline,
        title: "You can't ask for help on this task",
        message:
            'Only the assignee or an Admin can, while the task is open '
            'and the project is active.',
      );
    } else {
      body = NeedHelpForm(project: project, task: task);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Need Help')),
      body: body,
    );
  }
}
