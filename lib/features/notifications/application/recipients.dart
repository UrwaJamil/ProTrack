import '../../auth/data/app_user.dart';
import '../../projects/data/project.dart';
import '../../tasks/data/task.dart';

/// Leaders (Admins) of [project].
Set<String> projectAdmins(Project project) => {
  for (final e in project.members.entries)
    if (e.value == UserRole.leader) e.key,
};

/// Who hears about a new comment (Phase 8 decision D): the task's
/// assignees plus the project's Admins, minus the author. Assignees no
/// longer in the project are left out (the rules require a shared
/// project).
Set<String> commentRecipients(Project project, Task task, String authorUid) => {
  ...task.assignedTo.where(project.members.containsKey),
  ...projectAdmins(project),
}..remove(authorUid);

/// Who hears "Task X is blocked" (decision C): the project's Admins,
/// minus the requester and the named helper (who already gets the help
/// request).
Set<String> blockedRecipients(
  Project project, {
  required String requesterUid,
  String? helperUid,
}) => projectAdmins(project)
  ..remove(requesterUid)
  ..remove(helperUid);

/// For each approver of [requesterUid], a project the approver leads and
/// the requester is in (the notice's `projectId`; the rules require a
/// shared project). Active projects first.
Map<String, String> approverProjects(
  String requesterUid,
  Iterable<String> approverIds,
  Iterable<Project> projects,
) {
  final sorted = [
    ...projects.where((p) => !p.isArchived),
    ...projects.where((p) => p.isArchived),
  ];
  return {
    for (final approver in approverIds)
      if (sorted
              .where(
                (p) =>
                    p.members[approver] == UserRole.leader &&
                    p.members.containsKey(requesterUid),
              )
              .firstOrNull
          case final p?)
        approver: p.id,
  };
}
