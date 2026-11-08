import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/task_detail_screen.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/status_selector.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

final _task = testTask(
  description: 'Mockups for light and dark mode.',
  deadline: DateTime(2026, 10, 20),
  subtasks: const [
    Subtask(title: 'Wireframes', done: true),
    Subtask(title: 'Review'),
  ],
);

Future<FakeTaskRepository> _pump(
  WidgetTester tester, {
  required String uid,
  Task? task,
  Project? project,
  FakeTaskRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final taskRepo = repo ?? FakeTaskRepository([task ?? _task]);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Project page')),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId',
        builder: (_, state) => TaskDetailScreen(
          projectId: state.pathParameters['id']!,
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId/edit',
        builder: (_, _) => const Scaffold(body: Text('Edit form')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([project ?? testProject()]),
        ),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        userRepositoryProvider.overrideWithValue(testUsers()),
        currentUidProvider.overrideWithValue(uid),
        todayProvider.overrideWithValue(DateTime(2026, 10, 15)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push('/leader/projects/abcd1234/tasks/tid12345');
  await tester.pumpAndSettle();
  return taskRepo;
}

void main() {
  testWidgets('shows the details, deadline, assignee and subtasks (FR-3.4, '
      'FR-3.5)', (tester) async {
    await _pump(tester, uid: 'member2');
    expect(find.text('Design login screen'), findsOneWidget);
    expect(find.text('Mockups for light and dark mode.'), findsOneWidget);
    expect(find.text('Due Oct 20, 2026'), findsOneWidget);
    expect(find.text('5 days left'), findsOneWidget);
    expect(find.text('Mo Member'), findsOneWidget);
    expect(find.text('Wireframes'), findsOneWidget);
    expect(find.text('1 of 2 done'), findsOneWidget);
    expect(find.text('TSK-TID1'), findsOneWidget);
  });

  testWidgets('a Member not assigned gets the read-only view', (tester) async {
    await _pump(tester, uid: 'member2');
    expect(find.byType(StatusSelector), findsNothing);
    expect(
      find.text('Only the assignee or an Admin can change the status.'),
      findsOneWidget,
    );
    final box = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Review'),
    );
    expect(box.onChanged, isNull);
    expect(find.text('Edit'), findsNothing);
    expect(find.byTooltip('Delete task'), findsNothing);
  });

  testWidgets('the assignee changes status (FR-3.6) but cannot edit', (
    tester,
  ) async {
    final repo = await _pump(tester, uid: 'member1');
    expect(find.byType(StatusSelector), findsOneWidget);
    for (final label in [
      'Not Started',
      'In Progress',
      'On Hold',
      'Completed',
    ]) {
      expect(
        find.descendant(
          of: find.byType(StatusSelector),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    // Blocked waits for Phase 4.
    expect(find.text('Blocked'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(StatusSelector),
        matching: find.text('On Hold'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, ['updateStatus:on_hold']);
    expect(repo.tasks.values.single.status, TaskStatus.onHold);

    expect(find.text('Edit'), findsNothing);
    expect(find.byTooltip('Delete task'), findsNothing);
  });

  testWidgets('the assignee ticks a subtask', (tester) async {
    final repo = await _pump(tester, uid: 'member1');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Review'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['setSubtaskDone:1:true']);
    expect(find.text('2 of 2 done'), findsOneWidget);
  });

  testWidgets('Admins get Edit and Delete; delete asks first', (tester) async {
    final repo = await _pump(tester, uid: 'admin');
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byType(StatusSelector), findsOneWidget);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Design login screen"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['delete:tid12345']);
    expect(find.text('Project page'), findsOneWidget);
  });

  testWidgets('an overdue task is flagged', (tester) async {
    await _pump(
      tester,
      uid: 'member1',
      task: testTask(deadline: DateTime(2026, 10, 12)),
    );
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('3 days overdue'), findsOneWidget);
  });

  testWidgets('everything is read-only in an archived project', (tester) async {
    await _pump(
      tester,
      uid: 'admin',
      project: testProject(status: ProjectStatus.archived),
    );
    expect(find.text('This project is archived'), findsOneWidget);
    expect(find.byType(StatusSelector), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.byTooltip('Delete task'), findsNothing);
  });

  testWidgets('a failed status change reports an error', (tester) async {
    final repo = FakeTaskRepository([_task])..writeError = StateError('denied');
    await _pump(tester, uid: 'member1', repo: repo);
    await tester.tap(
      find.descendant(
        of: find.byType(StatusSelector),
        matching: find.text('Completed'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save the change. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('a deleted task shows "Task not found"', (tester) async {
    await _pump(tester, uid: 'member1', repo: FakeTaskRepository());
    expect(find.text('Task not found'), findsOneWidget);
  });

  testWidgets('a load error shows Retry', (tester) async {
    await _pump(
      tester,
      uid: 'member1',
      repo: FakeTaskRepository()..loadError = StateError('denied'),
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
