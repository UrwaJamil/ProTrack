import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/leader/screens/analytics_screen.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

final _today = DateTime(2026, 11, 9, 10);

/// admin leads Mobile App (newer) and Cloud Migration; "Archived" (led,
/// archived) and "Their Project" (admin is a Member) must not count.
final _mobile = testProject(
  id: 'mob1',
  name: 'Mobile App',
  createdAt: DateTime(2026, 10, 2),
  members: {'admin': UserRole.leader},
);
final _cloud = testProject(
  id: 'cld1',
  name: 'Cloud Migration',
  createdAt: DateTime(2026, 10, 1),
  members: {'admin': UserRole.leader},
);
final _archived = testProject(
  id: 'arc1',
  name: 'Archived',
  status: ProjectStatus.archived,
  members: {'admin': UserRole.leader},
);
final _theirs = testProject(
  id: 'thr1',
  name: 'Their Project',
  createdBy: 'm2',
  members: {'m2': UserRole.leader, 'admin': UserRole.member},
);

Task _task(
  String projectId,
  String id,
  TaskStatus status, {
  DateTime? deadline,
}) => testTask(
  id: id,
  projectId: projectId,
  status: status,
  deadline: deadline ?? DateTime(2026, 11, 20),
);

List<Task> _tasks() => [
  _task('mob1', 'm1', TaskStatus.completed),
  _task('mob1', 'm2', TaskStatus.completed),
  _task('mob1', 'm3', TaskStatus.completed),
  _task('mob1', 'm4', TaskStatus.inProgress, deadline: DateTime(2026, 11, 2)),
  _task('cld1', 'c1', TaskStatus.blocked),
  _task('cld1', 'c2', TaskStatus.onHold),
  _task('cld1', 'c3', TaskStatus.todo),
  _task('cld1', 'c4', TaskStatus.completed),
  _task('arc1', 'x1', TaskStatus.blocked),
  _task('thr1', 'x2', TaskStatus.blocked),
];

typedef _Fakes = ({FakeProjectRepository projects, FakeTaskRepository tasks});

Future<void> _pump(
  WidgetTester tester, {
  List<Project>? projects,
  List<Task>? tasks,
  void Function(_Fakes)? setup,
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakes = (
    projects: FakeProjectRepository(
      projects ?? [_mobile, _cloud, _archived, _theirs],
    ),
    tasks: FakeTaskRepository(tasks ?? _tasks()),
  );
  setup?.call(fakes);
  final router = GoRouter(
    initialLocation: '/leader/analytics',
    routes: [
      GoRoute(
        path: '/leader/analytics',
        builder: (_, _) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/leader/projects/:id',
        builder: (_, s) => Scaffold(body: Text('Project ${s.uri.path}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(fakes.projects),
        taskRepositoryProvider.overrideWithValue(fakes.tasks),
        currentUidProvider.overrideWithValue('admin'),
        todayProvider.overrideWithValue(_today),
      ],
      child: MaterialApp.router(
        theme: theme ?? AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('tiles, donut total, legend and progress (led, active only)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.text('Analytics & reports'), findsOneWidget);
    // 8 tasks in Mobile App + Cloud Migration; 4 completed = 50%.
    expect(find.bySemanticsLabel('Projects: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Completed %: 50%'), findsOneWidget);
    expect(find.bySemanticsLabel('Overdue: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Blocked: 1'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '8 tasks: 4 Completed, 1 In Progress, 1 On Hold, 1 Blocked, '
        '1 Not Started',
      ),
      findsOneWidget,
    );
    expect(find.text('Total Tasks'), findsOneWidget);
    expect(find.text('Not Started'), findsOneWidget);
    // Project list order (newest first); FR-2.5 progress.
    expect(find.text('Mobile App'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Mobile App')).dy,
      lessThan(tester.getTopLeft(find.text('Cloud Migration')).dy),
    );
    expect(find.text('Archived'), findsNothing);
    expect(find.text('Their Project'), findsNothing);
    semantics.dispose();
  });

  testWidgets('number colors: red Overdue, amber Blocked', (tester) async {
    await _pump(tester);
    final theme = AppTheme.lightTheme;
    Color? colorOf(String label) {
      // The stat tile comes first ("Blocked" is also in the legend).
      final tile = find
          .ancestor(of: find.text(label).first, matching: find.byType(Card))
          .first;
      final number = find.descendant(of: tile, matching: find.text('1'));
      return tester.widget<Text>(number).style?.color;
    }

    expect(colorOf('Overdue'), theme.colorScheme.error);
    expect(colorOf('Blocked'), theme.appColors.warning);
  });

  testWidgets('tapping a project opens it on the Admin dashboard', (
    tester,
  ) async {
    await _pump(tester);
    await tester.ensureVisible(find.text('Cloud Migration'));
    await tester.tap(find.text('Cloud Migration'));
    await tester.pumpAndSettle();
    expect(find.text('Project /leader/projects/cld1'), findsOneWidget);
  });

  testWidgets('dark theme renders without overflow', (tester) async {
    await _pump(tester, theme: AppTheme.darkTheme);
    expect(tester.takeException(), isNull);
    expect(find.text('Tasks by status'), findsOneWidget);
  });

  testWidgets('no tasks yet: zeros and an empty ring', (tester) async {
    await _pump(tester, tasks: const []);
    expect(find.text('Total Tasks'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(3)); // tile + two projects
  });

  testWidgets('empty state when I lead no active project', (tester) async {
    await _pump(tester, projects: [_archived, _theirs]);
    expect(find.text('No projects you lead'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    await _pump(tester, setup: (f) => f.tasks.neverLoad = true, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state with Retry', (tester) async {
    await _pump(tester, setup: (f) => f.tasks.loadError = StateError('x'));
    expect(find.text("We couldn't load your analytics."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
