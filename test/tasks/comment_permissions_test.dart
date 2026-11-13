import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/tasks/application/comment_permissions.dart';
import 'package:team_project_manager/features/tasks/data/task_comment.dart';

import '../support/project_fixtures.dart';

void main() {
  final project = testProject(); // admin = leader, member1 = member
  final byMember = TaskComment(
    id: 'c',
    authorId: 'member1',
    text: 'hi',
    createdAt: DateTime(2026),
  );

  test('members comment; outsiders cannot', () {
    expect(CommentPermissions(project, 'member1').canComment, isTrue);
    expect(CommentPermissions(project, 'admin').canComment, isTrue);
    expect(CommentPermissions(project, 'outsider').canComment, isFalse);
  });

  test('only the author edits', () {
    expect(CommentPermissions(project, 'member1').canEdit(byMember), isTrue);
    expect(CommentPermissions(project, 'admin').canEdit(byMember), isFalse);
  });

  test('the author or a project Admin deletes', () {
    expect(CommentPermissions(project, 'member1').canDelete(byMember), isTrue);
    expect(CommentPermissions(project, 'admin').canDelete(byMember), isTrue);
    expect(
      CommentPermissions(project, 'outsider').canDelete(byMember),
      isFalse,
    );
  });

  test('nothing is writable while the project is archived', () {
    final archived = testProject(status: ProjectStatus.archived);
    final p = CommentPermissions(archived, 'member1');
    expect(p.canComment, isFalse);
    expect(p.canEdit(byMember), isFalse);
    expect(p.canDelete(byMember), isFalse);
  });
}
