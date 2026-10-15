import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/data/project.dart';

import '../support/project_fixtures.dart';

void main() {
  group('Project map round trip', () {
    test('toCreateMap → fromMap keeps every field', () {
      final original = testProject();
      final map = {
        ...original.toCreateMap(),
        'createdAt': Timestamp.fromDate(original.createdAt),
      };
      final parsed = Project.fromMap(original.id, map);

      expect(parsed.name, original.name);
      expect(parsed.description, original.description);
      expect(parsed.startDate, original.startDate);
      expect(parsed.deadline, original.deadline);
      expect(parsed.status, ProjectStatus.active);
      expect(parsed.createdBy, 'admin');
      expect(parsed.members, original.members);
      expect(parsed.createdAt, original.createdAt);
    });

    test('stores roles as "leader"/"member" and memberIds = members keys', () {
      final map = testProject().toCreateMap();
      expect(map['members'], {'admin': 'leader', 'member1': 'member'});
      expect(
        (map['memberIds'] as List).toSet(),
        (map['members'] as Map).keys.toSet(),
      );
      expect(map['status'], 'active');
    });

    test('unknown member roles are skipped, not coerced', () {
      final p = Project.fromMap('x', {
        'members': {'a': 'leader', 'b': 'admin', 'c': 'pm'},
      });
      expect(p.members, {'a': UserRole.leader});
    });

    test('a pending server timestamp falls back instead of throwing', () {
      final p = Project.fromMap('x', {'createdAt': null});
      expect(p.createdAt, isNotNull);
    });
  });

  test('shortId is PRJ- plus the first 4 id characters, uppercased', () {
    expect(testProject(id: '7f3kQ9zz').shortId, 'PRJ-7F3K');
  });

  group('member changes keep members and memberIds in sync', () {
    void expectInSync(MemberChange c) {
      expect(c.memberIds.toSet(), c.members.keys.toSet());
      expect(c.memberIds.length, c.members.length);
    }

    test('add puts the user in both, as a Member', () {
      final c = addMemberChange(testProject(), 'newcomer');
      expect(c.members['newcomer'], 'member');
      expect(c.memberIds, contains('newcomer'));
      expect(c.members['admin'], 'leader');
      expectInSync(c);
    });

    test('adding someone already in the project throws', () {
      expect(
        () => addMemberChange(testProject(), 'member1'),
        throwsArgumentError,
      );
    });

    test('remove takes the user out of both', () {
      final c = removeMemberChange(testProject(), 'member1');
      expect(c.members.containsKey('member1'), isFalse);
      expect(c.memberIds, isNot(contains('member1')));
      expectInSync(c);
    });

    test('the creator or any Admin cannot be removed', () {
      final p = testProject(
        members: {
          'admin': UserRole.leader,
          'coadmin': UserRole.leader,
          'member1': UserRole.member,
        },
      );
      expect(() => removeMemberChange(p, 'admin'), throwsArgumentError);
      expect(() => removeMemberChange(p, 'coadmin'), throwsArgumentError);
    });

    test('removing someone not in the project throws', () {
      expect(
        () => removeMemberChange(testProject(), 'stranger'),
        throwsArgumentError,
      );
    });
  });
}
