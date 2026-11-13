import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/tasks/application/helper_ranking.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/task_fixtures.dart';

AppUser _user(String uid, String name) => AppUser(
  uid: uid,
  name: name,
  email: '$uid@example.com',
  defaultRole: UserRole.member,
  skillTags: const [],
  createdAt: DateTime(2026),
);

void main() {
  final profiles = {
    'me': _user('me', 'Me'),
    'busy': _user('busy', 'Busy Bee'),
    'free': _user('free', 'Free Fred'),
    'alsoFree': _user('alsoFree', 'Alice Free'),
  };
  final tasks = [
    testTask(id: 't1', assignedTo: ['busy', 'me']),
    testTask(id: 't2', assignedTo: ['busy']),
    // Completed work doesn't count.
    testTask(id: 't3', assignedTo: ['free'], status: TaskStatus.completed),
  ];

  List<String> rank({Set<String> unavailable = const {}}) => [
    for (final h in rankHelpers(
      memberIds: ['me', 'busy', 'free', 'alsoFree', 'noProfile'],
      profiles: profiles,
      projectTasks: tasks,
      requesterUid: 'me',
      unavailable: unavailable,
    ))
      h.user.uid,
  ];

  test('least busy first, ties by name, without me or missing profiles', () {
    expect(rank(), ['alsoFree', 'free', 'busy']);
  });

  test('counts only active tasks', () {
    final result = rankHelpers(
      memberIds: ['me', 'busy', 'free'],
      profiles: profiles,
      projectTasks: tasks,
      requesterUid: 'me',
    );
    expect(
      {for (final h in result) h.user.uid: h.activeTasks},
      {'free': 0, 'busy': 2},
    );
  });

  test('unavailable people (Phase 6: on leave) are left out', () {
    expect(rank(unavailable: {'alsoFree'}), ['free', 'busy']);
  });
}
