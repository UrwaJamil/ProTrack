import '../../auth/data/app_user.dart';
import '../../projects/data/project.dart';
import '../data/task.dart';

/// What [uid] may do with tasks in [project] — and, when given, with one
/// [task]. Like `ProjectPermissions`, decided by the project's `members`
/// map (CLAUDE.md decision 1), never by the route or the user's default
/// role. Firestore rules enforce the same split (decision 3):
///
/// * project Admins (`leader`) create, edit, reassign and delete tasks;
/// * an assignee may only change status and tick subtasks (and, from
///   Phase 4, the help note) on tasks assigned to them;
/// * nothing is writable while the project is archived.
class TaskPermissions {
  const TaskPermissions(this.project, this.uid, [this.task]);

  final Project project;
  final String uid;
  final Task? task;

  bool get isLeader => project.members[uid] == UserRole.leader;

  bool get _writable => !project.isArchived;

  /// Assigned to [task] and still in the project. Someone removed from the
  /// project is unassigned at the same time, but the membership check keeps
  /// a stale assignment powerless anyway (the rules check it too).
  bool get isAssignee =>
      task != null &&
      task!.isAssignedTo(uid) &&
      project.members.containsKey(uid);

  /// FR-3.1.
  bool get canCreate => isLeader && _writable;

  /// Title, required work, assignees, deadline, priority, subtask list
  /// (FR-3.2, FR-3.3, FR-3.5).
  bool get canEdit => task != null && isLeader && _writable;

  bool get canDelete => task != null && isLeader && _writable;

  /// FR-3.6.
  bool get canUpdateStatus =>
      task != null && _writable && (isLeader || isAssignee);

  /// FR-3.5: tick portions of the work as done.
  bool get canToggleSubtasks => canUpdateStatus;
}
