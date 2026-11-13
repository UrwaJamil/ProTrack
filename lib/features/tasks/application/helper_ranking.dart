import '../../auth/data/app_user.dart';
import '../data/task.dart';

/// One row of Need Help's "Who can help?" list.
typedef HelperCandidate = ({AppUser user, int activeTasks});

/// "Who can help?" (Phase 4 decision, docs/PLAN.md): the project's
/// members except [requesterUid], least busy first — fewest active
/// (not completed) tasks in [projectTasks] — then by name. Members whose
/// profile is missing are left out.
///
/// [unavailable] removes people outright; from Phase 6 it holds whoever
/// is on approved leave today.
///
/// Only this project's tasks are counted: rules don't let the requester
/// read other projects' tasks.
List<HelperCandidate> rankHelpers({
  required Iterable<String> memberIds,
  required Map<String, AppUser> profiles,
  required Iterable<Task> projectTasks,
  required String requesterUid,
  Set<String> unavailable = const {},
}) {
  final active = <String, int>{};
  for (final task in projectTasks) {
    if (task.isCompleted) continue;
    for (final uid in task.assignedTo) {
      active[uid] = (active[uid] ?? 0) + 1;
    }
  }
  final result = <HelperCandidate>[
    for (final uid in memberIds.toSet())
      if (uid != requesterUid && !unavailable.contains(uid))
        if (profiles[uid] case final user?)
          (user: user, activeTasks: active[uid] ?? 0),
  ];
  result.sort((a, b) {
    final byLoad = a.activeTasks.compareTo(b.activeTasks);
    if (byLoad != 0) return byLoad;
    return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
  });
  return result;
}
