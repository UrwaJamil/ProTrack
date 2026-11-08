import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/projects/presentation/projects_overview_screen.dart';
import 'package:team_project_manager/features/projects/presentation/widgets/project_card_skeleton.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';

import '../support/fake_auth.dart';
import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/project_fixtures.dart';

Widget _app({
  required FakeProjectRepository projects,
  required bool adminView,
  String uid = 'admin',
}) {
  final users = FakeUserRepository();
  for (final (id, name) in [('admin', 'Ada Admin'), ('member1', 'Mo Member')]) {
    users.docs[id] = AppUser(
      uid: id,
      name: name,
      email: '$id@example.com',
      defaultRole: UserRole.member,
      skillTags: const [],
      createdAt: DateTime(2026),
    ).toMap();
  }
  return ProviderScope(
    overrides: [
      projectRepositoryProvider.overrideWithValue(projects),
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
      userRepositoryProvider.overrideWithValue(users),
      currentUidProvider.overrideWithValue(uid),
      todayProvider.overrideWithValue(DateTime(2026, 10, 15)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: ProjectsOverviewScreen(adminView: adminView),
    ),
  );
}

Finder _chip(String label, int count) =>
    find.bySemanticsLabel('$label, $count');

void main() {
  testWidgets('shows skeleton cards while loading', (tester) async {
    final repo = FakeProjectRepository()..neverLoad = true;
    await tester.pumpWidget(_app(projects: repo, adminView: true));
    await tester.pump();
    expect(find.byType(ProjectCardSkeleton), findsWidgets);
  });

  testWidgets('shows an error with Retry when loading fails', (tester) async {
    final repo = FakeProjectRepository()..loadError = StateError('offline');
    await tester.pumpWidget(_app(projects: repo, adminView: true));
    await tester.pumpAndSettle();
    expect(find.text("We couldn't load your projects."), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('Admin empty state offers New Project', (tester) async {
    await tester.pumpWidget(
      _app(projects: FakeProjectRepository(), adminView: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Admin View'), findsOneWidget);
    // The empty-state button and the floating button.
    expect(find.text('New Project'), findsNWidgets(2));
  });

  testWidgets('Member empty state explains, with no create controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(projects: FakeProjectRepository(), adminView: false, uid: 'm'),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Projects'), findsOneWidget);
    expect(find.text('Admin View'), findsNothing);
    expect(
      find.text('Projects appear here once an Admin adds you to one.'),
      findsOneWidget,
    );
    expect(find.text('New Project'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  group('with projects', () {
    late FakeProjectRepository repo;

    setUp(() {
      repo = FakeProjectRepository([
        testProject(
          id: 'aaaa1',
          name: 'On Track',
          deadline: DateTime(2026, 12, 1),
        ),
        testProject(
          id: 'bbbb2',
          name: 'Running Late',
          deadline: DateTime(2026, 10, 1),
        ),
        testProject(
          id: 'cccc3',
          name: 'Old Stuff',
          status: ProjectStatus.archived,
        ),
        testProject(
          id: 'dddd4',
          name: 'Joined Project',
          createdBy: 'other',
          members: {'other': UserRole.leader, 'admin': UserRole.member},
        ),
      ]);
    });

    testWidgets('counts: All = Active + Overdue, Archived separate', (
      tester,
    ) async {
      await tester.pumpWidget(_app(projects: repo, adminView: true));
      await tester.pumpAndSettle();
      expect(_chip('All', 3), findsOneWidget);
      expect(_chip('Active', 2), findsOneWidget);
      expect(_chip('Overdue', 1), findsOneWidget);
      expect(_chip('Archived', 1), findsOneWidget);
      expect(find.text('Old Stuff'), findsNothing);
    });

    testWidgets('Overdue chip shows only overdue projects, marked as such', (
      tester,
    ) async {
      await tester.pumpWidget(_app(projects: repo, adminView: true));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Overdue', 1));
      await tester.pumpAndSettle();
      expect(find.text('Running Late'), findsOneWidget);
      expect(find.text('On Track'), findsNothing);
      expect(find.text('Overdue'), findsWidgets);
    });

    testWidgets("My Projects shows only projects I joined but didn't create", (
      tester,
    ) async {
      await tester.pumpWidget(_app(projects: repo, adminView: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Projects'));
      await tester.pumpAndSettle();
      expect(find.text('Joined Project'), findsOneWidget);
      expect(find.text('On Track'), findsNothing);
      expect(_chip('All', 1), findsOneWidget);
    });

    testWidgets('cards show the short id and member avatars', (tester) async {
      await tester.pumpWidget(_app(projects: repo, adminView: true));
      await tester.pumpAndSettle();
      expect(find.text('PRJ-AAAA'), findsOneWidget);
      expect(find.text('AA'), findsWidgets); // Ada Admin's initials
    });
  });
}
