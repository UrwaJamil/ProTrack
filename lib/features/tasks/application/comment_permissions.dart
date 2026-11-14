import '../../auth/data/app_user.dart';
import '../../projects/data/project.dart';
import '../data/task_comment.dart';

/// What [uid] may do with a task's comments in [project]. Firestore
/// rules enforce the same (decision 3 style): project members comment
/// while the project is active; the author edits their own comment; the
/// author or a project Admin deletes it.
class CommentPermissions {
  const CommentPermissions(this.project, this.uid);

  final Project project;
  final String uid;

  bool get _active => !project.isArchived;

  bool get isLeader => project.members[uid] == UserRole.leader;

  bool get canComment => _active && project.members.containsKey(uid);

  bool canEdit(TaskComment c) => _active && c.authorId == uid;

  bool canDelete(TaskComment c) => _active && (c.authorId == uid || isLeader);
}
