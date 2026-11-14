import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/team/application/team_providers.dart';
import 'package:team_project_manager/features/team/presentation/widgets/add_to_project_sheet.dart';

import '../support/project_fixtures.dart';
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
  final led = testProject(
    id: 'p1',
    members: {
      'admin': UserRole.leader,
      'admin2': UserRole.leader,
      'm1': UserRole.member,
      'm2': UserRole.member,
    },
  );
  final notLed = testProject(
    id: 'p2',
    createdBy: 'boss',
    members: {
      'boss': UserRole.leader,
      'admin': UserRole.member,
      'm3': UserRole.member,
    },
  );
  final archived = testProject(
    id: 'p3',
    status: ProjectStatus.archived,
    members: {'admin': UserRole.leader, 'm4': UserRole.member},
  );
  final profiles = {
    for (final (id, name) in [
      ('admin2', 'Abe Admin'),
      ('m1', 'Zed Member'),
      ('m2', 'amy member'),
      ('m3', 'Outside'),
      ('m4', 'Archived'),
    ])
      id: _user(id, name),
  };

  test('team = people in active projects I lead, minus me, by name', () {
    final team = buildTeam(
      me: 'admin',
      projects: [led, notLed, archived],
      profiles: profiles,
      tasks: [
        testTask(id: 'a', assignedTo: ['m1']),
        testTask(id: 'b', assignedTo: ['m1', 'm2']),
        testTask(id: 'c', assignedTo: ['m1'], status: TaskStatus.completed),
      ],
    );
    expect(team.map((m) => m.user.uid), ['admin2', 'm2', 'm1']);
    expect(team.first.role, UserRole.leader);
    expect(team.last.activeTasks, 2);
    expect(team[1].activeTasks, 1);
    expect(teamUids('admin', [led, notLed, archived]), {'admin2', 'm1', 'm2'});
  });

  test('people without a profile are left out', () {
    final team = buildTeam(
      me: 'admin',
      projects: [led],
      profiles: {'m1': profiles['m1']!},
      tasks: const [],
    );
    expect(team.map((m) => m.user.uid), ['m1']);
  });

  test('search matches name or email, case-insensitively', () {
    final team = buildTeam(
      me: 'admin',
      projects: [led],
      profiles: profiles,
      tasks: const [],
    );
    expect(filterTeam(team, '  AMY ').map((m) => m.user.uid), ['m2']);
    expect(filterTeam(team, 'm1@').map((m) => m.user.uid), ['m1']);
    expect(filterTeam(team, ''), team);
    expect(filterTeam(team, 'nobody'), isEmpty);
  });

  test('Add to project offers active projects I lead that they are not in', () {
    final other = testProject(
      id: 'p5',
      name: 'Another',
      members: {'admin': UserRole.leader},
    );
    expect(
      projectsToAddTo('admin', 'm1', [
        led,
        notLed,
        archived,
        other,
      ]).map((p) => p.id),
      ['p5'],
    );
    expect(projectsToAddTo('admin', 'm3', [led, notLed]).map((p) => p.id), [
      'p1',
    ]);
  });
}
