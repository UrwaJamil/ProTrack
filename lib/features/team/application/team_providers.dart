import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../../tasks/application/task_filters.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/task.dart';

/// One row of the Admin's Team tab.
typedef TeamMember = ({AppUser user, UserRole role, int activeTasks});

/// A task with its project, for Member Profile's "Current tasks".
typedef TeamTask = ({Task task, Project project});

/// Every task in the signed-in user's non-archived projects (the ones the
/// rules let them read), with its project.
final teamTasksProvider = Provider<AsyncValue<List<TeamTask>>>((ref) {
  final projects = ref.watch(myProjectsProvider);
  if (projects.hasError) {
    return AsyncError(projects.error!, projects.stackTrace!);
  }
  final list = projects.value;
  if (list == null) return const AsyncLoading();
  final result = <TeamTask>[];
  for (final project in list.where((p) => !p.isArchived)) {
    final tasks = ref.watch(projectTasksProvider(project.id));
    if (tasks.hasError) return AsyncError(tasks.error!, tasks.stackTrace!);
    final value = tasks.value;
    if (value == null) return const AsyncLoading();
    result.addAll([for (final t in value) (task: t, project: project)]);
  }
  return AsyncData(result);
});

/// The people in the non-archived projects the signed-in user leads,
/// without themselves. [TeamMember.role] is Admin if they lead any of
/// those projects, else Member; active tasks are open tasks across every
/// project the signed-in user can read.
List<TeamMember> buildTeam({
  required String me,
  required Iterable<Project> projects,
  required Map<String, AppUser> profiles,
  required Iterable<Task> tasks,
}) {
  final roles = <String, UserRole>{};
  for (final p in projects) {
    if (p.isArchived || p.members[me] != UserRole.leader) continue;
    for (final e in p.members.entries) {
      if (e.key == me) continue;
      if (roles[e.key] != UserRole.leader) roles[e.key] = e.value;
    }
  }
  final active = <String, int>{};
  for (final t in tasks) {
    if (t.isCompleted) continue;
    for (final uid in t.assignedTo) {
      active[uid] = (active[uid] ?? 0) + 1;
    }
  }
  return [
    for (final e in roles.entries)
      if (profiles[e.key] case final user?)
        (user: user, role: e.value, activeTasks: active[e.key] ?? 0),
  ]..sort(
    (a, b) => a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase()),
  );
}

/// Uids [buildTeam] considers, before profiles are loaded.
Set<String> teamUids(String me, Iterable<Project> projects) => {
  for (final p in projects)
    if (!p.isArchived && p.members[me] == UserRole.leader)
      for (final uid in p.memberIds)
        if (uid != me) uid,
};

/// The Admin's Team tab.
final teamProvider = Provider<AsyncValue<List<TeamMember>>>((ref) {
  final me = ref.watch(currentUidProvider) ?? '';
  final projects = ref.watch(myProjectsProvider);
  final tasks = ref.watch(teamTasksProvider);
  final uids = teamUids(me, projects.value ?? const []);
  final profiles = ref.watch(userProfilesProvider(profilesKey(uids)));
  for (final a in [projects, tasks, profiles]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  }
  final p = projects.value;
  final t = tasks.value;
  final u = profiles.value;
  if (p == null || t == null || u == null) return const AsyncLoading();
  return AsyncData(
    buildTeam(me: me, projects: p, profiles: u, tasks: t.map((e) => e.task)),
  );
});

/// Name / email search on the Team tab (case-insensitive substring).
List<TeamMember> filterTeam(List<TeamMember> team, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return team;
  return [
    for (final m in team)
      if (m.user.name.toLowerCase().contains(q) ||
          m.user.email.toLowerCase().contains(q))
        m,
  ];
}

/// [uid]'s tasks in projects the signed-in user can read: open first by
/// deadline, then completed.
final memberTasksProvider = Provider.family<AsyncValue<List<TeamTask>>, String>(
  (ref, uid) {
    return ref.watch(teamTasksProvider).whenData((all) {
      final mine = [
        for (final t in all)
          if (t.task.isAssignedTo(uid)) t,
      ];
      final order = sortTasks(mine.map((e) => e.task).toList());
      final byTask = {for (final t in mine) t.task: t};
      return [for (final t in order) byTask[t]!];
    });
  },
);
