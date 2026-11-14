import '../../auth/data/app_user.dart';
import '../../projects/data/project.dart';
import '../../tasks/data/task.dart';
import '../data/working_days.dart';

/// Who may approve [uid]'s leave: the leaders of their active projects,
/// minus themselves, sorted for a stable payload. Empty means "No
/// approver available".
List<String> approverIdsFor(String uid, Iterable<Project> projects) {
  final ids = <String>{
    for (final p in projects)
      if (!p.isArchived && p.members.containsKey(uid))
        for (final e in p.members.entries)
          if (e.value == UserRole.leader && e.key != uid) e.key,
  };
  return ids.toList()..sort();
}

/// The project through which [deciderUid] leads [requesterUid] (the
/// rules' `decidedVia`): an active one if possible. `null` when they no
/// longer share a project the decider leads.
Project? decidingProjectFor(
  String deciderUid,
  String requesterUid,
  Iterable<Project> projects,
) {
  Project? archived;
  for (final p in projects) {
    if (p.members[deciderUid] != UserRole.leader) continue;
    if (!p.members.containsKey(requesterUid)) continue;
    if (!p.isArchived) return p;
    archived ??= p;
  }
  return archived;
}

/// Open tasks assigned to [uid] whose deadline day falls in
/// [from]–[to]: the deadline-conflict warning. Doesn't block anything.
List<Task> tasksDueDuring(
  Iterable<Task> tasks, {
  required String uid,
  required DateTime from,
  required DateTime to,
}) {
  final a = dayOf(from);
  final b = dayOf(to);
  return [
    for (final t in tasks)
      if (!t.isCompleted &&
          t.isAssignedTo(uid) &&
          !dayOf(t.deadline).isBefore(a) &&
          !dayOf(t.deadline).isAfter(b))
        t,
  ]..sort((x, y) => x.deadline.compareTo(y.deadline));
}
