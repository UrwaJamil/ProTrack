import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../../tasks/application/task_filters.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/task.dart';

typedef CalendarTask = ({Task task, Project project});

/// Active projects the signed-in user leads (Phase 7: the Calendar shows
/// their tasks; archived projects are left out).
final ledProjectsProvider = Provider<AsyncValue<List<Project>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref
      .watch(myProjectsProvider)
      .whenData(
        (projects) => [
          for (final p in projects)
            if (!p.isArchived &&
                uid != null &&
                p.members[uid] == UserRole.leader)
              p,
        ],
      );
});

/// Every task of [ledProjectsProvider]'s projects, merged from the
/// existing per-project `projectTasksProvider`. Loading until every
/// project's tasks are in; an error if any of them fails.
final calendarTasksProvider = Provider<AsyncValue<List<CalendarTask>>>((ref) {
  final projects = ref.watch(ledProjectsProvider);
  final list = projects.value;
  if (list == null) {
    return projects.hasError
        ? AsyncValue.error(projects.error!, projects.stackTrace!)
        : const AsyncValue.loading();
  }
  final all = <CalendarTask>[];
  for (final p in list) {
    final tasks = ref.watch(projectTasksProvider(p.id));
    if (tasks.hasError) {
      return AsyncValue.error(tasks.error!, tasks.stackTrace!);
    }
    final value = tasks.value;
    if (value == null) return const AsyncValue.loading();
    all.addAll([for (final t in value) (task: t, project: p)]);
  }
  return AsyncValue.data(all);
});

/// Midnight of [d]'s day.
DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// The 42 days (6 weeks, Monday first) shown for [month]'s grid,
/// including the neighbouring months' days.
List<DateTime> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month);
  // DateTime.weekday: Monday = 1 … Sunday = 7.
  final lead = first.weekday - DateTime.monday;
  return [
    for (var i = 0; i < 42; i++)
      DateTime(first.year, first.month, first.day - lead + i),
  ];
}

/// The dot under a day.
enum DayMarker { none, due, overdue }

/// Tasks grouped by their deadline day, each day in display order
/// ([compareTasks]).
Map<DateTime, List<CalendarTask>> tasksByDay(Iterable<CalendarTask> tasks) {
  final byDay = <DateTime, List<CalendarTask>>{};
  for (final t in tasks) {
    byDay.putIfAbsent(calendarDay(t.task.deadline), () => []).add(t);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => compareTasks(a.task, b.task));
  }
  return byDay;
}

/// Red if any task due that day is overdue, else a plain dot if any is
/// due (completed ones included).
DayMarker dayMarker(List<CalendarTask>? tasks, {required DateTime today}) {
  if (tasks == null || tasks.isEmpty) return DayMarker.none;
  return tasks.any((t) => isTaskOverdue(t.task, today: today))
      ? DayMarker.overdue
      : DayMarker.due;
}

/// "Mobile App • Ayesha Noor", "… • Ayesha Noor +1", or "… • Unassigned".
/// Names come from [names]; an unknown uid shows as "Unknown". While
/// [names] is `null` (still loading), just the project name.
String calendarTaskSubtitle(CalendarTask t, Map<String, AppUser>? names) {
  final ids = t.task.assignedTo;
  if (names == null && ids.isNotEmpty) return t.project.name;
  final who = ids.isEmpty
      ? 'Unassigned'
      : '${names?[ids.first]?.name ?? 'Unknown'}'
            '${ids.length > 1 ? ' +${ids.length - 1}' : ''}';
  return '${t.project.name} • $who';
}
