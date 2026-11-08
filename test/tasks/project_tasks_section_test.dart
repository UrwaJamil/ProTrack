import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/projects/presentation/project_detail_screen.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/task_card.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

Future<FakeTaskRepository> _pump(
  WidgetTester tester, {
  required String uid,
  List<Task> tasks = const [],
  Project? project,
  FakeTaskRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final taskRepo = repo ?? FakeTaskRepository(tasks);
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
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProjectDetailScreen(projectId: 'abcd1234'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taskRepo;
}

void main() {
  testWidgets('lists the project tasks, open ones first', (tester) async {
    await _pump(
      tester,
      uid: 'member1',
      tasks: [
        testTask(id: 'done', title: 'Ship it', status: TaskStatus.completed),
        testTask(id: 'open', title: 'Design login screen'),
      ],
    );
    expect(find.byType(TaskCard), findsNWidgets(2));
    final titles = tester
        .widgetList<TaskCard>(find.byType(TaskCard))
        .map((c) => c.task.title);
    expect(titles, ['Design login screen', 'Ship it']);
    expect(find.text('Not Started'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('progress is now the real share of completed tasks (FR-2.5)', (
    tester,
  ) async {
    await _pump(
      tester,
      uid: 'member1',
      tasks: [
        testTask(id: 'a', status: TaskStatus.completed),
        testTask(id: 'b', status: TaskStatus.completed),
        testTask(id: 'c', status: TaskStatus.onHold),
        testTask(id: 'd', status: TaskStatus.inProgress),
      ],
    );
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('an overdue task shows the Overdue badge', (tester) async {
    await _pump(
      tester,
      uid: 'member1',
      tasks: [
        testTask(id: 'late', deadline: DateTime(2026, 10, 10)),
        testTask(
          id: 'lateDone',
          deadline: DateTime(2026, 10, 10),
          status: TaskStatus.completed,
        ),
      ],
    );
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('Admins get "Add task"; Members do not', (tester) async {
    await _pump(tester, uid: 'admin');
    expect(find.text('Add task'), findsOneWidget);
    expect(find.textContaining('Break the project into tasks'), findsOneWidget);
  });

  testWidgets('Members see the read-only empty state', (tester) async {
    await _pump(tester, uid: 'member1');
    expect(find.text('Add task'), findsNothing);
    expect(find.text('No tasks yet.'), findsOneWidget);
  });

  testWidgets('no "Add task" on an archived project', (tester) async {
    await _pump(
      tester,
      uid: 'admin',
      project: testProject(status: ProjectStatus.archived),
    );
    expect(find.text('Add task'), findsNothing);
  });

  testWidgets('an Admin added as a Member of someone else\'s project gets no '
      '"Add task"', (tester) async {
    await _pump(
      tester,
      uid: 'admin2',
      project: testProject(
        members: {'admin': UserRole.leader, 'admin2': UserRole.member},
      ),
    );
    expect(find.text('Add task'), findsNothing);
  });

  testWidgets('a load error shows Retry', (tester) async {
    await _pump(
      tester,
      uid: 'member1',
      repo: FakeTaskRepository()..loadError = StateError('offline'),
    );
    expect(find.text("We couldn't load the tasks."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
