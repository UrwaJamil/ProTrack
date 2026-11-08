import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../data/task.dart';
import '../data/task_repository.dart';
import 'task_filters.dart';

/// Every task in a project, in display order ([compareTasks]). Also the
/// input to the project's progress (FR-2.5).
final projectTasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, projectId) =>
      ref.watch(taskRepositoryProvider).watchTasks(projectId).map(sortTasks),
);

typedef TaskKey = ({String projectId, String taskId});

/// One task, live; `null` once deleted or if it never existed.
final taskProvider = StreamProvider.family<Task?, TaskKey>(
  (ref, key) =>
      ref.watch(taskRepositoryProvider).watchTask(key.projectId, key.taskId),
);

/// Raw collection-group result: every task assigned to the signed-in user.
final assignedTasksProvider = StreamProvider<List<Task>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchAssignedTo(uid);
});

typedef AssignedTask = ({Task task, Project project});

/// The Member's "My Tasks" (FR-3.4): assigned tasks with their project,
/// in display order. Tasks whose project the user is no longer in, or
/// whose project is archived (read-only), are left out.
final myTasksProvider = Provider<AsyncValue<List<AssignedTask>>>((ref) {
  final tasks = ref.watch(assignedTasksProvider);
  final projects = ref.watch(myProjectsProvider);
  final taskList = tasks.value;
  final projectList = projects.value;
  if (taskList != null && projectList != null) {
    final byId = {
      for (final p in projectList)
        if (!p.isArchived) p.id: p,
    };
    return AsyncData([
      for (final task in sortTasks(taskList))
        if (byId[task.projectId] case final project?)
          (task: task, project: project),
    ]);
  }
  if (tasks.hasError) return AsyncError(tasks.error!, tasks.stackTrace!);
  if (projects.hasError) {
    return AsyncError(projects.error!, projects.stackTrace!);
  }
  return const AsyncLoading();
});
