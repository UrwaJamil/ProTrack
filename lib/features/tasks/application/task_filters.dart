import '../../projects/application/project_filters.dart';
import '../data/task.dart';
import '../data/task_priority.dart';

/// Computed on read, never stored: the deadline day has passed and the
/// task isn't completed.
bool isTaskOverdue(Task task, {required DateTime today}) =>
    !task.isCompleted && daysRemaining(task.deadline, today) < 0;

/// Display order: open tasks first, earliest deadline first (so overdue
/// ones lead), then higher priority, then title. Completed tasks follow
/// in the same order.
int compareTasks(Task a, Task b) {
  if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
  final byDeadline = a.deadline.compareTo(b.deadline);
  if (byDeadline != 0) return byDeadline;
  final byPriority = TaskPriority.values
      .indexOf(a.priority)
      .compareTo(TaskPriority.values.indexOf(b.priority));
  if (byPriority != 0) return byPriority;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

List<Task> sortTasks(Iterable<Task> tasks) =>
    tasks.toList()..sort(compareTasks);
