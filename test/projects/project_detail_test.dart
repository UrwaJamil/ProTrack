import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/projects/presentation/project_detail_screen.dart';
import 'package:team_project_manager/features/projects/presentation/widgets/assign_member_search.dart';
import 'package:team_project_manager/features/projects/presentation/widgets/team_members_section.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';

import '../support/fake_auth.dart';
import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/finders.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

FakeUserRepository _users() {
  final users = FakeUserRepository();
  for (final (id, name) in [
    ('admin', 'Ada Admin'),
    ('member1', 'Mo Member'),
    ('sam', 'Sam Searchable'),
    ('sal', 'Sally Second'),
  ]) {
    users.docs[id] = AppUser(
      uid: id,
      name: name,
      email: '$id@example.com',
      defaultRole: UserRole.member,
      skillTags: const [],
      createdAt: DateTime(2026),
    ).toMap();
  }
  return users;
}

Future<FakeProjectRepository> _pump(
  WidgetTester tester, {
  required String uid,
  List<Task> tasks = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeProjectRepository([testProject(id: 'abcd1234')]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(repo),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
        userRepositoryProvider.overrideWithValue(_users()),
        currentUidProvider.overrideWithValue(uid),
        todayProvider.overrideWithValue(DateTime(2026, 10, 15)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProjectDetailScreen(projectId: 'abcd1234'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('shows the summary: name, id, date range, days left, progress', (
    tester,
  ) async {
    await _pump(tester, uid: 'member1');
    expect(find.text('Mobile App Redesign'), findsOneWidget);
    expect(find.text('PRJ-ABCD'), findsOneWidget);
    expect(find.text('Oct 1 – Nov 28, 2026'), findsOneWidget);
    expect(find.text('44 days left'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('a project Member gets the read-only view', (tester) async {
    await _pump(tester, uid: 'member1');
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Add'), findsNothing);
    expect(find.byType(AssignMemberSearch), findsNothing);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
    // Still sees who is on the team.
    expect(find.text('Ada Admin'), findsOneWidget);
    expect(find.text('Mo Member (you)'), findsOneWidget);
  });

  testWidgets('Admin: lock on Admin rows, remove on Member rows', (
    tester,
  ) async {
    await _pump(tester, uid: 'admin');
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('removing a Member asks first, then updates the list', (
    tester,
  ) async {
    final repo = await _pump(tester, uid: 'admin');
    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Remove Mo Member?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['removeMember:member1']);
    expect(repo.projects['abcd1234']!.members.keys, ['admin']);
    expect(find.text('Mo Member'), findsNothing);
  });

  testWidgets('the remove dialog says how many tasks they lose', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'admin',
      tasks: [
        testTask(id: 't1'),
        testTask(id: 't2'),
        testTask(id: 't3', assignedTo: const ['admin']),
      ],
    );
    final remove = find.byIcon(Icons.person_remove_outlined);
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'They will lose access to "Mobile App Redesign" and be unassigned '
        'from 2 tasks. You can add them again later.',
      ),
      findsOneWidget,
    );
  });

  test('removeMemberMessage', () {
    expect(
      removeMemberMessage('P', 0),
      'They will lose access to "P". You can add them again later.',
    );
    expect(
      removeMemberMessage('P', 1),
      'They will lose access to "P" and be unassigned from 1 task. '
      'You can add them again later.',
    );
  });

  group('Assign Team Member search', () {
    testWidgets('waits for 3 characters before searching', (tester) async {
      await _pump(tester, uid: 'admin');
      await tester.enterText(fieldWithHint('Search by email'), 'sa');
      await tester.pump(memberSearchDebounce);
      expect(find.textContaining('Type at least 3 characters'), findsOneWidget);
      expect(find.text('Sam Searchable'), findsNothing);
    });

    testWidgets('lists matches by email prefix and adds one as a Member', (
      tester,
    ) async {
      final repo = await _pump(tester, uid: 'admin');
      await tester.enterText(fieldWithHint('Search by email'), 'SA');
      await tester.enterText(fieldWithHint('Search by email'), 'SAM@');
      await tester.pump(memberSearchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('Sam Searchable'), findsOneWidget);
      expect(find.text('Sally Second'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['addMember:sam']);
      expect(repo.projects['abcd1234']!.members['sam'], UserRole.member);
      // Now in the team list, and no longer offered.
      expect(find.text('Sam Searchable'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add'), findsNothing);
    });

    testWidgets('people already in the project are not offered', (
      tester,
    ) async {
      await _pump(tester, uid: 'admin');
      await tester.enterText(fieldWithHint('Search by email'), 'member1');
      await tester.pump(memberSearchDebounce);
      await tester.pumpAndSettle();
      expect(
        find.text('Everyone matching "member1" is already in this project.'),
        findsOneWidget,
      );
    });

    testWidgets('no match explains only registered users can be added', (
      tester,
    ) async {
      await _pump(tester, uid: 'admin');
      await tester.enterText(fieldWithHint('Search by email'), 'nobody');
      await tester.pump(memberSearchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('No registered user matches "nobody".'), findsOneWidget);
    });
  });
}
