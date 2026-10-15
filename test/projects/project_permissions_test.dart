import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/application/project_permissions.dart';
import 'package:team_project_manager/features/projects/data/project.dart';

import '../support/project_fixtures.dart';

void main() {
  final project = testProject(
    members: {
      'admin': UserRole.leader,
      'coadmin': UserRole.leader,
      'member1': UserRole.member,
    },
  );

  group('project Admin (leader)', () {
    final p = ProjectPermissions(project, 'admin');

    test('can edit, archive, delete and manage members', () {
      expect(p.isLeader, isTrue);
      expect(p.canEditDetails, isTrue);
      expect(p.canArchiveOrRestore, isTrue);
      expect(p.canDelete, isTrue);
      expect(p.canManageMembers, isTrue);
    });

    test('can add people not yet in the project', () {
      expect(p.canAddMember('newcomer'), isTrue);
      expect(p.canAddMember('member1'), isFalse);
    });

    test('can remove Members, but never an Admin or the creator', () {
      expect(p.canRemoveMember('member1'), isTrue);
      expect(p.canRemoveMember('coadmin'), isFalse);
      expect(p.canRemoveMember('admin'), isFalse);
      expect(p.canRemoveMember('stranger'), isFalse);
    });
  });

  test('a second Admin has the same rights but still cannot remove the '
      'creator', () {
    final p = ProjectPermissions(project, 'coadmin');
    expect(p.canEditDetails, isTrue);
    expect(p.canRemoveMember('admin'), isFalse);
  });

  test('a Member can only read', () {
    final p = ProjectPermissions(project, 'member1');
    expect(p.isMember, isTrue);
    expect(p.isLeader, isFalse);
    expect(p.canEditDetails, isFalse);
    expect(p.canArchiveOrRestore, isFalse);
    expect(p.canDelete, isFalse);
    expect(p.canManageMembers, isFalse);
    expect(p.canAddMember('newcomer'), isFalse);
    expect(p.canRemoveMember('member1'), isFalse);
  });

  test("the user's default role doesn't matter — only the project's "
      'members map does', () {
    // `member1` might be an Admin by defaultRole, yet is a Member here.
    final p = ProjectPermissions(project, 'member1');
    expect(p.canEditDetails, isFalse);
  });

  test('outsiders get nothing', () {
    final p = ProjectPermissions(project, 'stranger');
    expect(p.isMember, isFalse);
    expect(p.canDelete, isFalse);
  });

  test('archived: Admins may restore or delete, but not edit or change '
      'members', () {
    final archived = testProject(status: ProjectStatus.archived);
    final p = ProjectPermissions(archived, 'admin');
    expect(p.canArchiveOrRestore, isTrue);
    expect(p.canDelete, isTrue);
    expect(p.canEditDetails, isFalse);
    expect(p.canManageMembers, isFalse);
    expect(p.canRemoveMember('member1'), isFalse);
  });
}
