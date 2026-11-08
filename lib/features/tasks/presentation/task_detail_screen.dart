import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/task_permissions.dart';
import '../application/tasks_providers.dart';
import 'task_paths.dart';
import 'task_ui_actions.dart';
import 'widgets/task_detail_body.dart';

/// One task, for both dashboards (`/leader/projects/:id/tasks/:tid` and
/// `/member/projects/:id/tasks/:tid`) — FR-3.4, FR-3.5, FR-3.6. What's
/// allowed comes from the project's `members` map and the task's
/// assignees ([TaskPermissions]), never from the route: Admins get Edit /
/// Delete, the assignee gets the status selector and checkable subtasks,
/// everyone else the read-only view.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({
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
    final permissions = project == null
        ? null
        : TaskPermissions(project, uid, task);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (permissions?.canEdit ?? false)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              ),
              onPressed: () => context.push(editTaskPath(projectId, taskId)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          if (permissions?.canDelete ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: 'Delete task',
                onPressed: () => confirmDeleteTask(context, ref, task!),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
        ],
      ),
      body: _body(ref, projectAsync, taskAsync, permissions),
    );
  }

  Widget _body(
    WidgetRef ref,
    AsyncValue<Object?> projectAsync,
    AsyncValue<Object?> taskAsync,
    TaskPermissions? permissions,
  ) {
    // Includes losing access (removed from the project): the rules then
    // refuse the read.
    if (projectAsync.hasError || taskAsync.hasError) {
      return ErrorState(
        message:
            "We couldn't load this task. You may no longer have access "
            'to it.',
        onRetry: () {
          ref.invalidate(projectProvider(projectId));
          ref.invalidate(taskProvider(_key));
        },
      );
    }
    if (!projectAsync.hasValue || !taskAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final task = permissions?.task;
    if (permissions == null || task == null) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Task not found',
        message: 'It may have been deleted.',
      );
    }
    return TaskDetailBody(task: task, permissions: permissions);
  }
}
