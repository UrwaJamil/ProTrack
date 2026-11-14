import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/leader/screens/calendar_screen.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

/// Monday, Nov 9 2026.
final _today = DateTime(2026, 11, 9, 10);

/// admin leads "Mobile App"; "Archived" (led, archived) and "Their
/// Project" (admin is a Member) must not show.
final _led = testProject(
  id: 'led1',
  name: 'Mobile App',
  members: {'admin': UserRole.leader, 'member1': UserRole.member},
);
final _archived = testProject(
  id: 'arch1',
  name: 'Archived',
  status: ProjectStatus.archived,
  members: {'admin': UserRole.leader},
);
final _theirs = testProject(
  id: 'their1',
  name: 'Their Project',
  createdBy: 'member2',
  members: {'member2': UserRole.leader, 'admin': UserRole.member},
);

List<Task> _tasks() => [
  testTask(
    id: 'today1',
    projectId: 'led1',
    title: 'Design login flow',
    status: TaskStatus.inProgress,
    deadline: DateTime(2026, 11, 9, 17),
    assignedTo: ['member1'],
  ),
  testTask(
    id: 'today2',
    projectId: 'led1',
    title: 'Review schema',
    status: TaskStatus.completed,
    deadline: DateTime(2026, 11, 9),
    assignedTo: const [],
  ),
  testTask(
    id: 'late1',
    projectId: 'led1',
    title: 'Firestore rules',
    status: TaskStatus.todo,
    deadline: DateTime(2026, 11, 6),
  ),
  testTask(
    id: 'dec1',
    projectId: 'led1',
    title: 'December task',
    deadline: DateTime(2026, 12, 3),
  ),
  testTask(
    id: 'arch',
    projectId: 'arch1',
    title: 'Archived task',
    deadline: DateTime(2026, 11, 9),
  ),
  testTask(
    id: 'their',
    projectId: 'their1',
    title: 'Their task',
    deadline: DateTime(2026, 11, 9),
  ),
];

typedef _Fakes = ({FakeProjectRepository projects, FakeTaskRepository tasks});

Future<_Fakes> _pump(
  WidgetTester tester, {
  List<Project>? projects,
  void Function(_Fakes)? setup,
}) async {
  tester.view.physicalSize = const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakes = (
    projects: FakeProjectRepository(projects ?? [_led, _archived, _theirs]),
    tasks: FakeTaskRepository(_tasks()),
  );
  setup?.call(fakes);
  final router = GoRouter(
    initialLocation: '/leader/calendar',
    routes: [
      GoRoute(
        path: '/leader/calendar',
        builder: (_, _) => const Scaffold(body: CalendarScreen()),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId',
        builder: (_, s) => Scaffold(body: Text('Task ${s.uri.path}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(fakes.projects),
        taskRepositoryProvider.overrideWithValue(fakes.tasks),
        userRepositoryProvider.overrideWithValue(testUsers()),
        currentUidProvider.overrideWithValue('admin'),
        todayProvider.overrideWithValue(_today),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakes;
}

Finder _dot(String kind, DateTime day) =>
    find.byKey(ValueKey('dot-$kind-${day.toIso8601String()}'));

void main() {
  testWidgets('month card, today selected, its tasks from led projects', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Tasks on selected day'), findsOneWidget);
    expect(find.text('Design login flow'), findsOneWidget);
    expect(find.text('Review schema'), findsOneWidget);
    // Open first, then completed.
    expect(
      tester.getTopLeft(find.text('Design login flow')).dy,
      lessThan(tester.getTopLeft(find.text('Review schema')).dy),
    );
    expect(find.text('Mobile App • Mo Member'), findsOneWidget);
    expect(find.text('Mobile App • Unassigned'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    // Archived and Member-only projects are left out.
    expect(find.text('Archived task'), findsNothing);
    expect(find.text('Their task'), findsNothing);
  });

  testWidgets('dots: plain for due days, red for overdue ones', (tester) async {
    await _pump(tester);
    expect(_dot('due', DateTime(2026, 11, 9)), findsOneWidget);
    expect(_dot('overdue', DateTime(2026, 11, 6)), findsOneWidget);
    // Dec 3 shows greyed in November's last row, with its dot.
    expect(_dot('due', DateTime(2026, 12, 3)), findsOneWidget);
    expect(_dot('due', DateTime(2026, 11, 10)), findsNothing);
    expect(_dot('overdue', DateTime(2026, 11, 10)), findsNothing);
  });

  testWidgets('selecting an overdue day shows the Overdue pill', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('6').first);
    await tester.pumpAndSettle();
    expect(find.text('Firestore rules'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Design login flow'), findsNothing);
  });

  testWidgets('an empty day says so', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
    expect(find.text('No tasks due on this day'), findsOneWidget);
  });

  testWidgets('prev / next change the month', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('tapping a greyed next-month day jumps to that month', (
    tester,
  ) async {
    await _pump(tester);
    // "3" appears for Nov 3 and for the greyed Dec 3; the last is Dec.
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('December task'), findsOneWidget);
  });

  testWidgets('tapping a task opens it on the Admin dashboard', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Design login flow'));
    await tester.pumpAndSettle();
    expect(
      find.text('Task /leader/projects/led1/tasks/today1'),
      findsOneWidget,
    );
  });

  testWidgets('day cells have a screen-reader label', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Friday, Nov 6, 1 task due, overdue'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Monday, Nov 9, today, 2 tasks due'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('empty state when I lead no active project', (tester) async {
    await _pump(tester, projects: [_archived, _theirs]);
    expect(find.text('No projects you lead'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.reset);
    final projects = FakeProjectRepository([_led])..neverLoad = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(projects),
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          currentUidProvider.overrideWithValue('admin'),
          todayProvider.overrideWithValue(_today),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state with Retry when tasks fail', (tester) async {
    await _pump(tester, setup: (f) => f.tasks.loadError = StateError('x'));
    expect(find.text("We couldn't load your calendar."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
