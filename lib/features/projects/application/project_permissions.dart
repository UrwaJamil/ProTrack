import '../../auth/data/app_user.dart';
import '../data/project.dart';

/// What [uid] may do with [project]. Decided by the project's own
/// `members` map (CLAUDE.md decision 1), never by the user's default role
/// or the current route — an Admin added as a Member to someone else's
/// project gets the read-only view. Firestore rules enforce the same
/// leader-only writes server-side.
class ProjectPermissions {
  const ProjectPermissions(this.project, this.uid);

  final Project project;
  final String uid;

  bool get isMember => project.members.containsKey(uid);

  /// A project Admin (`leader` in `members`).
  bool get isLeader => project.members[uid] == UserRole.leader;

  /// Edit name/description/dates. Archived projects are read-only until
  /// restored.
  bool get canEditDetails => isLeader && !project.isArchived;

  bool get canArchiveOrRestore => isLeader;

  bool get canDelete => isLeader;

  bool get canManageMembers => isLeader && !project.isArchived;

  bool canAddMember(String targetUid) =>
      canManageMembers && !project.members.containsKey(targetUid);

  /// Only plain Members can be removed — never an Admin, and never the
  /// project's creator.
  bool canRemoveMember(String targetUid) =>
      canManageMembers &&
      targetUid != project.createdBy &&
      project.members[targetUid] == UserRole.member;
}
