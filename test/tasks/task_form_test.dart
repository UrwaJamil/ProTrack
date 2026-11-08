import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_priority.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/task_form_screen.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/finders.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

Future<void> _pumpForm(
  WidgetTester tester, {
  required FakeTaskRepository repo,
  required String location,
  String uid = 'admin',
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Project page')),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/new',
        builder: (_, state) =>
            TaskFormScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId',
        builder: (_, state) =>
            Scaffold(body: Text('Task ${state.pathParameters['taskId']}')),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId/edit',
        builder: (_, state) => TaskFormScreen(
          projectId: state.pathParameters['id']!,
          taskId: state.pathParameters['taskId'],
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([testProject()]),
        ),
        taskRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(testUsers()),
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
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickDay(WidgetTester tester, String day) async {
  await _tapVisible(tester, fieldWithHint('Select a date'));
  await tester.tap(find.text(day).last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title, deadline and an assignee are required', (tester) async {
    final repo = FakeTaskRepository();
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/tasks/new',
    );
    expect(find.text('New Task'), findsOneWidget);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create Task'));

    expect(find.text('Enter a task title'), findsOneWidget);
    expect(find.text('Pick a deadline'), findsOneWidget);
    expect(find.text('Assign at least one team member'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('creates a task with assignee, priority and subtasks, then '
      'opens it (FR-3.1–3.3, FR-3.5)', (tester) async {
    final repo = FakeTaskRepository();
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/tasks/new',
    );

    await tester.enterText(
      fieldWithHint('e.g. Design the login screen'),
      '  Build API  ',
    );
    await tester.enterText(
      fieldWithHint('What needs to be done, and what "done" looks like'),
      'REST endpoints for tasks',
    );
    await _pickDay(tester, '20');
    await _tapVisible(tester, find.text('High'));
    await _tapVisible(tester, find.text('Mo Member'));
    await _tapVisible(tester, find.text('Add subtask'));
    await tester.enterText(fieldWithHint('Subtask 1'), 'Schema');
    await _tapVisible(tester, find.text('Add subtask'));
    await tester.enterText(fieldWithHint('Subtask 2'), '   ');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Create Task'));

    expect(repo.calls, ['create']);
    final task = repo.tasks.values.single;
    expect(task.title, 'Build API');
    expect(task.description, 'REST endpoints for tasks');
    expect(task.assignedTo, ['member1']);
    expect(task.priority, TaskPriority.high);
    expect(task.status, TaskStatus.todo);
    expect(task.deadline.day, 20);
    // The blank row is dropped.
    expect(task.subtasks, const [Subtask(title: 'Schema')]);
    expect(task.createdBy, 'admin');
    expect(find.text('Task ${task.id}'), findsOneWidget);
  });

  testWidgets('edit prefills, saves, and keeps the status', (tester) async {
    final repo = FakeTaskRepository([
      testTask(
        status: TaskStatus.inProgress,
        subtasks: const [Subtask(title: 'Wireframes', done: true)],
      ),
    ]);
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/tasks/tid12345/edit',
    );
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Design login screen'), findsOneWidget);
    expect(find.text('Wireframes'), findsOneWidget);

    await tester.enterText(
      fieldWithHint('e.g. Design the login screen'),
      'Design auth screens',
    );
    // Reassign: member1 -> admin.
    await _tapVisible(tester, find.text('Mo Member'));
    await _tapVisible(tester, find.text('Ada Admin · Admin'));
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save Changes'),
    );

    expect(repo.calls, ['update:tid12345']);
    final task = repo.tasks.values.single;
    expect(task.title, 'Design auth screens');
    expect(task.assignedTo, ['admin']);
    expect(task.status, TaskStatus.inProgress);
    expect(task.subtasks, const [Subtask(title: 'Wireframes', done: true)]);
    expect(find.text('Project page'), findsOneWidget);
  });

  testWidgets('a Member is refused the form', (tester) async {
    await _pumpForm(
      tester,
      repo: FakeTaskRepository([testTask()]),
      location: '/leader/projects/abcd1234/tasks/tid12345/edit',
      uid: 'member1',
    );
    expect(find.text('Admins only'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });

  testWidgets('a save failure shows an error and stays', (tester) async {
    final repo = FakeTaskRepository([testTask()])
      ..writeError = StateError('denied');
    await _pumpForm(
      tester,
      repo: repo,
      location: '/leader/projects/abcd1234/tasks/tid12345/edit',
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    expect(
      find.text("We couldn't save your changes. Please try again."),
      findsOneWidget,
    );
  });
}
