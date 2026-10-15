import '../../tasks/data/task_status.dart';

/// Project progress (FR-2.5): the share of the project's tasks that are
/// completed, as a whole percentage (rounded down, so 100 means every task
/// is done). A project with no tasks is 0%.
int computeProgress(Iterable<TaskStatus> taskStatuses) {
  var total = 0;
  var completed = 0;
  for (final status in taskStatuses) {
    total++;
    if (status == TaskStatus.completed) completed++;
  }
  if (total == 0) return 0;
  return (completed * 100) ~/ total;
}
