import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/projects/presentation/project_form_screen.dart';
import 'package:team_project_manager/features/projects/presentation/widgets/project_form_fields.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/finders.dart';
import '../support/project_fixtures.dart';

/// The form behind a minimal router: starts on a stand-in list page and
/// pushes [location], so the screen's `pop` has somewhere to go.
Future<GoRouter> _pumpForm(
  WidgetTester tester, {
  required FakeProjectRepository repo,
  required String location,
  String uid = 'admin',
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('List page')),
      ),
      GoRoute(
        path: '/leader/projects',
        builder: (_, _) => const Scaffold(body: Text('Projects page')),
      ),
      GoRoute(
        path: '/leader/projects/new',
        builder: (_, _) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: '/leader/projects/:id',
        builder: (_, state) => Text('Detail ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/leader/projects/:id/edit',
        builder: (_, state) =>
            ProjectFormScreen(projectId: state.pathParameters['id']),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(repo),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        currentUidProvider.overrideWithValue(uid),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push(location);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('validateDeadline', () {
    final start = DateTime(2026, 10, 1);

    test('requires a deadline', () {
      expect(validateDeadline(start, null), 'Pick a deadline');
    });

    test('deadline must be strictly after the start date', () {
      expect(
        validateDeadline(start, DateTime(2026, 9, 30)),
        'Deadline must be after the start date',
      );
      expect(
        validateDeadline(start, start),
        'Deadline must be after the start date',
      );
      expect(validateDeadline(start, DateTime(2026, 10, 2)), isNull);
    });
  });

  testWidgets('New Project: name and deadline are required', (tester) async {
    final repo = FakeProjectRepository();
    await _pumpForm(tester, repo: repo, location: '/leader/projects/new');

    expect(find.text('New Project'), findsOneWidget);
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Create Project'),
    );

    expect(find.text('Enter a project name'), findsOneWidget);
    expect(find.text('Pick a deadline'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('Edit Project: pre-filled, saves and goes back', (tester) async {
    final repo = FakeProjectRepository([testProject(id: 'abcd1234')]);
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/edit',
    );

    expect(find.text('Edit Project'), findsOneWidget);
    expect(find.text('PRJ-ABCD'), findsOneWidget);
    expect(find.text('Mobile App Redesign'), findsOneWidget);

    await tester.enterText(
      fieldWithHint('e.g. Mobile App Redesign'),
      'Renamed Project',
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save Changes'),
    );

    expect(repo.calls, ['updateDetails']);
    expect(repo.projects['abcd1234']!.name, 'Renamed Project');
    expect(find.text('List page'), findsOneWidget);
  });

  testWidgets('a project Member cannot open the edit form', (tester) async {
    final repo = FakeProjectRepository([testProject(id: 'abcd1234')]);
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/edit',
      uid: 'member1',
    );
    expect(find.text('Admins only'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('archived: read-only fields and Restore instead of Archive', (
    tester,
  ) async {
    final repo = FakeProjectRepository([
      testProject(id: 'abcd1234', status: ProjectStatus.archived),
    ]);
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/edit',
    );
    expect(find.text('This project is archived'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    await _tapVisible(tester, find.text('Restore Project'));
    expect(repo.calls, ['setStatus:active']);
  });

  testWidgets('delete is refused while the project has tasks', (tester) async {
    final repo = FakeProjectRepository([testProject(id: 'abcd1234')])
      ..withTasks.add('abcd1234');
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/edit',
    );
    await _tapVisible(tester, find.text('Delete Project'));
    expect(find.text("Can't delete this project"), findsOneWidget);
    expect(repo.calls, isNot(contains('delete')));
  });

  testWidgets('delete asks for confirmation naming the project and members', (
    tester,
  ) async {
    final repo = FakeProjectRepository([testProject(id: 'abcd1234')]);
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/edit',
    );
    await _tapVisible(tester, find.text('Delete Project'));

    expect(find.text('Delete "Mobile App Redesign"?'), findsOneWidget);
    expect(find.textContaining('removes access for 1 member'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await _tapVisible(tester, find.text('Delete Project'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['delete']);
    expect(repo.projects, isEmpty);
    expect(find.text('Projects page'), findsOneWidget);
  });
}
