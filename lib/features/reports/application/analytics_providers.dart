import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_providers.dart';
import '../../projects/application/progress.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../../tasks/application/task_filters.dart';
import '../../tasks/data/task_status.dart';

typedef ProjectProgress = ({Project project, int percent});

/// The Admin's Analytics (Phase 9) over the active projects they lead.
class TeamAnalytics {
  const TeamAnalytics({
    required this.projectCount,
    required this.countsByStatus,
    required this.overdue,
    required this.projectProgress,
  });

  final int projectCount;

  /// Every [TaskStatus], 0 when none.
  final Map<TaskStatus, int> countsByStatus;
  final int overdue;

  /// In the project list's order (newest first).
  final List<ProjectProgress> projectProgress;

  int get totalTasks => countsByStatus.values.fold(0, (a, b) => a + b);
  int get blocked => countsByStatus[TaskStatus.blocked] ?? 0;

  /// Completed share of all tasks, rounded down like FR-2.5 progress.
  int get completedPercent => computeProgress([
    for (final e in countsByStatus.entries)
      for (var i = 0; i < e.value; i++) e.key,
  ]);
}

/// Pure: [projects] in display order, [tasks] from those projects.
TeamAnalytics computeAnalytics(
  List<Project> projects,
  List<CalendarTask> tasks, {
  required DateTime today,
}) {
  final counts = {for (final s in TaskStatus.values) s: 0};
  final byProject = <String, List<TaskStatus>>{};
  var overdue = 0;
  for (final t in tasks) {
    counts[t.task.status] = counts[t.task.status]! + 1;
    byProject.putIfAbsent(t.project.id, () => []).add(t.task.status);
    if (isTaskOverdue(t.task, today: today)) overdue++;
  }
  return TeamAnalytics(
    projectCount: projects.length,
    countsByStatus: counts,
    overdue: overdue,
    projectProgress: [
      for (final p in projects)
        (project: p, percent: computeProgress(byProject[p.id] ?? const [])),
    ],
  );
}

/// [computeAnalytics] over the Phase 7 `ledProjectsProvider` /
/// `calendarTasksProvider` (active projects I lead and all their tasks).
final analyticsProvider = Provider<AsyncValue<TeamAnalytics>>((ref) {
  final projects = ref.watch(ledProjectsProvider);
  final tasks = ref.watch(calendarTasksProvider);
  final today = ref.watch(todayProvider);
  final projectList = projects.value;
  final taskList = tasks.value;
  if (projectList != null && taskList != null) {
    return AsyncValue.data(
      computeAnalytics(projectList, taskList, today: today),
    );
  }
  if (projects.hasError) {
    return AsyncValue.error(projects.error!, projects.stackTrace!);
  }
  if (tasks.hasError) return AsyncValue.error(tasks.error!, tasks.stackTrace!);
  return const AsyncValue.loading();
});
