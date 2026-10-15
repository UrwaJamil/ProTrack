import '../data/project.dart';

/// Strips the time, in UTC so day arithmetic ignores DST shifts.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Whole days from [today] until [deadline]: 0 = due today, negative =
/// that many days overdue.
int daysRemaining(DateTime deadline, DateTime today) =>
    dateOnly(deadline).difference(dateOnly(today)).inDays;

/// Overdue is computed on read, never stored: an active project whose
/// deadline day has passed and that isn't finished.
bool isOverdue(
  Project project, {
  required DateTime today,
  required int progress,
}) =>
    !project.isArchived &&
    daysRemaining(project.deadline, today) < 0 &&
    progress < 100;

/// The filter chips. All = every non-archived project; Active and Overdue
/// split All between them; Archived is counted separately.
enum ProjectFilter { all, active, overdue, archived }

/// The Admin's "All Projects" / "My Projects" toggle. Mine = projects the
/// user is in but didn't create.
enum ProjectScope { all, mine }

typedef ProgressOf = int Function(Project project);

ProjectFilter _bucket(Project p, DateTime today, ProgressOf progressOf) {
  if (p.isArchived) return ProjectFilter.archived;
  return isOverdue(p, today: today, progress: progressOf(p))
      ? ProjectFilter.overdue
      : ProjectFilter.active;
}

bool matchesFilter(
  Project p,
  ProjectFilter filter, {
  required DateTime today,
  required ProgressOf progressOf,
}) {
  final bucket = _bucket(p, today, progressOf);
  return filter == ProjectFilter.all
      ? bucket != ProjectFilter.archived
      : bucket == filter;
}

Map<ProjectFilter, int> filterCounts(
  Iterable<Project> projects, {
  required DateTime today,
  required ProgressOf progressOf,
}) {
  final counts = {for (final f in ProjectFilter.values) f: 0};
  for (final p in projects) {
    for (final f in ProjectFilter.values) {
      if (matchesFilter(p, f, today: today, progressOf: progressOf)) {
        counts[f] = counts[f]! + 1;
      }
    }
  }
  return counts;
}

List<Project> applyScope(
  Iterable<Project> projects,
  ProjectScope scope,
  String uid,
) => switch (scope) {
  ProjectScope.all => projects.toList(),
  ProjectScope.mine =>
    projects
        .where((p) => p.members.containsKey(uid) && p.createdBy != uid)
        .toList(),
};
