import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/tasks_providers.dart';
import 'widgets/task_activity_body.dart';

/// Comments / History for one task (Phase 4, mock 01), on both
/// dashboards (`…/tasks/:taskId/activity`). Opened from Task Details.
/// What the viewer may do comes from the project's `members` map, never
/// the route.
class TaskActivityScreen extends ConsumerWidget {
  const TaskActivityScreen({
    super.key,
    required this.projectId,
    required this.taskId,
  });

  final String projectId;
  final String taskId;

  TaskKey get _key => (projectId: projectId, taskId: taskId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectProvider(projectId));
    final taskAsync = ref.watch(taskProvider(_key));

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
    } else if (projectAsync.value == null || taskAsync.value == null) {
      body = const EmptyState(
        icon: Icons.search_off,
        title: 'Task not found',
        message: 'It may have been deleted.',
      );
    } else {
      body = TaskActivityBody(
        project: projectAsync.value!,
        task: taskAsync.value!,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: body,
    );
  }
}
