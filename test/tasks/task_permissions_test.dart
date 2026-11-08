import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/tasks/application/task_permissions.dart';

import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

void main() {
  // admin = creator/Admin, admin2 = second Admin, member1 = assignee,
  // member2 = Member not assigned, outsider = not in the project.
  final project = testProject(
    members: {
      'admin': UserRole.leader,
      'admin2': UserRole.leader,
      'member1': UserRole.member,
      'member2': UserRole.member,
    },
  );
  final task = testTask(assignedTo: const ['member1']);

  TaskPermissions perms(String uid, {Project? p, bool withTask = true}) =>
      TaskPermissions(p ?? project, uid, withTask ? task : null);

  test('project Admins have full control of tasks', () {
    for (final uid in ['admin', 'admin2']) {
      final p = perms(uid);
      expect(p.isLeader, isTrue, reason: uid);
      expect(p.canCreate, isTrue, reason: uid);
      expect(p.canEdit, isTrue, reason: uid);
      expect(p.canDelete, isTrue, reason: uid);
      expect(p.canUpdateStatus, isTrue, reason: uid);
      expect(p.canToggleSubtasks, isTrue, reason: uid);
    }
  });

  test('the assignee may only update status and tick subtasks', () {
    final p = perms('member1');
    expect(p.isAssignee, isTrue);
    expect(p.canUpdateStatus, isTrue);
    expect(p.canToggleSubtasks, isTrue);
    expect(p.canCreate, isFalse);
    expect(p.canEdit, isFalse);
    expect(p.canDelete, isFalse);
  });

  test('a Member not assigned to the task gets read-only', () {
    final p = perms('member2');
    expect(p.isAssignee, isFalse);
    expect(p.canUpdateStatus, isFalse);
    expect(p.canToggleSubtasks, isFalse);
    expect(p.canEdit, isFalse);
  });

  test('someone outside the project can do nothing, even if still listed '
      'as an assignee', () {
    final stale = TaskPermissions(
      project,
      'outsider',
      testTask(assignedTo: const ['outsider']),
    );
    expect(stale.isAssignee, isFalse);
    expect(stale.canUpdateStatus, isFalse);
    expect(stale.canCreate, isFalse);
  });

  test('role comes from the project, not the default role: an Admin added '
      'as a Member who is assigned only gets assignee rights', () {
    final p = TaskPermissions(
      testProject(
        members: {'owner': UserRole.leader, 'otherAdmin': UserRole.member},
        createdBy: 'owner',
      ),
      'otherAdmin',
      testTask(assignedTo: const ['otherAdmin']),
    );
    expect(p.isLeader, isFalse);
    expect(p.canUpdateStatus, isTrue);
    expect(p.canEdit, isFalse);
  });

  test('nothing is writable while the project is archived', () {
    final archived = testProject(
      members: project.members,
      status: ProjectStatus.archived,
    );
    for (final uid in ['admin', 'member1']) {
      final p = perms(uid, p: archived);
      expect(p.canCreate, isFalse, reason: uid);
      expect(p.canEdit, isFalse, reason: uid);
      expect(p.canDelete, isFalse, reason: uid);
      expect(p.canUpdateStatus, isFalse, reason: uid);
      expect(p.canToggleSubtasks, isFalse, reason: uid);
    }
  });

  test('without a task only canCreate applies', () {
    final p = perms('admin', withTask: false);
    expect(p.canCreate, isTrue);
    expect(p.canEdit, isFalse);
    expect(p.canUpdateStatus, isFalse);
  });
}
