import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/my_tasks_screen.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/task_card.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeTaskRepository repo) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/member/tasks',
    routes: [
      GoRoute(
        path: '/member/tasks',
        builder: (_, _) => const Scaffold(body: MyTasksScreen()),
      ),
      GoRoute(
        path: '/member/projects/:id/tasks/:taskId',
        builder: (_, state) => Scaffold(
          body: Text(
            'Detail ${state.pathParameters['id']}/'
            '${state.pathParameters['taskId']}',
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([
            testProject(id: 'abcd1234'),
            testProject(id: 'efgh5678', name: 'Website Launch'),
          ]),
        ),
        taskRepositoryProvider.overrideWithValue(repo),
        userRepositoryProvider.overrideWithValue(testUsers()),
        currentUidProvider.overrideWithValue('member1'),
        todayProvider.overrideWithValue(DateTime(2026, 10, 15)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _titles(WidgetTester tester) => [
  for (final c in tester.widgetList<TaskCard>(find.byType(TaskCard)))
    c.task.title,
];

void main() {
  testWidgets('lists only my tasks across projects, overdue first, completed '
      'last (FR-3.4)', (tester) async {
    await _pump(
      tester,
      FakeTaskRepository([
        testTask(id: 'a', title: 'Later', deadline: DateTime(2026, 10, 25)),
        testTask(
          id: 'b',
          projectId: 'efgh5678',
          title: 'Late one',
          deadline: DateTime(2026, 10, 10),
        ),
        testTask(
          id: 'c',
          title: 'Done one',
          status: TaskStatus.completed,
          deadline: DateTime(2026, 10, 1),
        ),
        testTask(id: 'd', title: 'Not mine', assignedTo: const ['member2']),
      ]),
    );
    expect(_titles(tester), ['Late one', 'Later', 'Done one']);
    expect(find.text('2 open · 1 overdue'), findsOneWidget);
    expect(find.text('Website Launch'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('shows subtask progress on the card (FR-3.5)', (tester) async {
    await _pump(
      tester,
      FakeTaskRepository([
        testTask(
          subtasks: const [
            Subtask(title: 'One', done: true),
            Subtask(title: 'Two'),
            Subtask(title: 'Three'),
          ],
        ),
      ]),
    );
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('tapping a task opens it on the Member dashboard', (
    tester,
  ) async {
    await _pump(tester, FakeTaskRepository([testTask(id: 't1')]));
    await tester.tap(find.byType(TaskCard));
    await tester.pumpAndSettle();
    expect(find.text('Detail abcd1234/t1'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, FakeTaskRepository());
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('all completed shows "All caught up"', (tester) async {
    await _pump(
      tester,
      FakeTaskRepository([testTask(status: TaskStatus.completed)]),
    );
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('error state with Retry', (tester) async {
    await _pump(tester, FakeTaskRepository()..loadError = StateError('x'));
    expect(find.text("We couldn't load your tasks."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          taskRepositoryProvider.overrideWithValue(
            FakeTaskRepository()..neverLoad = true,
          ),
          currentUidProvider.overrideWithValue('member1'),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: MyTasksScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
