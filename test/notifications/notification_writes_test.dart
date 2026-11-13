import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/dev_preview/fakes/preview_leave_repository.dart';
import 'package:team_project_manager/dev_preview/fakes/preview_notification_repository.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/leave/data/leave_repository.dart';
import 'package:team_project_manager/features/leave/data/leave_type.dart';
import 'package:team_project_manager/features/leave/presentation/leave_request_form_screen.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_activity_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/need_help_screen.dart';
import 'package:team_project_manager/features/tasks/presentation/task_activity_screen.dart';

import '../support/fake_projects.dart';
import '../support/fake_task_activity.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

/// Phase 8: the flows that write notices (comments, Need Help, Request
/// Leave) send them to the right people, and the sink shows them in the
/// notification center's repository.
///
/// admin + admin2 lead; member1 is the assignee; member2 isn't assigned.
final _project = testProject(
  members: {
    'admin': UserRole.leader,
    'admin2': UserRole.leader,
    'member1': UserRole.member,
    'member2': UserRole.member,
  },
);

const _base = '/member/projects/abcd1234/tasks/tid12345';

typedef _Fakes = ({
  FakeTaskActivityRepository activity,
  PreviewLeaveRepository leave,
  PreviewNotificationRepository sink,
});

Future<_Fakes> _pump(
  WidgetTester tester, {
  required String uid,
  required String path,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sink = PreviewNotificationRepository();
  final tasks = FakeTaskRepository([testTask(status: TaskStatus.inProgress)]);
  final activity = FakeTaskActivityRepository(tasks, sink: sink);
  final leave = PreviewLeaveRepository(sink: sink);
  String param(GoRouterState s, String k) => s.pathParameters[k]!;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/member/projects/:id/tasks/:taskId/activity',
        builder: (_, s) => TaskActivityScreen(
          projectId: param(s, 'id'),
          taskId: param(s, 'taskId'),
        ),
      ),
      GoRoute(
        path: '/member/projects/:id/tasks/:taskId/help',
        builder: (_, s) => NeedHelpScreen(
          projectId: param(s, 'id'),
          taskId: param(s, 'taskId'),
        ),
      ),
      GoRoute(
        path: '/member/leave/new',
        builder: (_, _) => const LeaveRequestFormScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([_project]),
        ),
        taskRepositoryProvider.overrideWithValue(tasks),
        taskActivityRepositoryProvider.overrideWithValue(activity),
        leaveRepositoryProvider.overrideWithValue(leave),
        userRepositoryProvider.overrideWithValue(testUsers()),
        currentUidProvider.overrideWithValue(uid),
        todayProvider.overrideWithValue(DateTime(2026, 11, 9, 10)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push(path);
  await tester.pumpAndSettle();
  return (activity: activity, leave: leave, sink: sink);
}

void main() {
  testWidgets('a comment notifies the assignee and Admins, not the author', (
    tester,
  ) async {
    final fakes = await _pump(tester, uid: 'member2', path: '$_base/activity');
    await tester.enterText(find.byType(TextField), 'On it');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();

    final notices = fakes.activity.notifications.values;
    expect(notices.map((n) => n['userId']).toSet(), {
      'member1',
      'admin',
      'admin2',
    });
    for (final n in notices) {
      expect(n['type'], 'comment_added');
      expect(n['senderId'], 'member2');
      expect(n['message'], 'Mia Member commented on Design login screen');
      expect(n['detail'], 'On it');
      expect(n['commentId'], isA<String>());
    }
    expect(fakes.sink.docs.length, 3);
  });

  testWidgets('Need Help notifies the Admins (task_blocked) and the helper', (
    tester,
  ) async {
    final fakes = await _pump(tester, uid: 'member1', path: '$_base/activity');
    await tester.tap(find.text('Need help?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rules tests fail');
    await tester.tap(find.text('Mia Member'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Request Help'));
    await tester.pumpAndSettle();

    final byType = <String, Set<String>>{};
    for (final n in fakes.activity.notifications.values) {
      byType
          .putIfAbsent(n['type'] as String, () => {})
          .add(n['userId'] as String);
    }
    expect(byType, {
      'help_requested': {'member2'},
      'task_blocked': {'admin', 'admin2'},
    });
    final blocked = fakes.activity.notifications.values.firstWhere(
      (n) => n['type'] == 'task_blocked',
    );
    expect(blocked['message'], 'Task Design login screen is blocked');
    expect(blocked['detail'], 'Rules tests fail');
  });

  testWidgets('Request Leave notifies each approver through a shared '
      'project', (tester) async {
    final fakes = await _pump(
      tester,
      uid: 'member1',
      path: '/member/leave/new',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
    await tester.pumpAndSettle();
    for (final (hint, day) in [('Start', '1'), ('End', '2')]) {
      await tester.tap(find.widgetWithText(TextFormField, hint));
      await tester.pumpAndSettle();
      await tester.tap(find.text(day).first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextFormField).last, 'Conference');
    final button = find.widgetWithText(FilledButton, 'Submit Request');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final sent = fakes.leave.requests.values.single;
    expect(sent.status, LeaveStatus.pending);
    final notices = fakes.leave.notifications;
    expect(notices.keys.toSet(), {
      'leave_requested_${sent.id}_admin',
      'leave_requested_${sent.id}_admin2',
    });
    for (final n in notices.values) {
      expect(n['type'], 'leave_requested');
      expect(n['projectId'], 'abcd1234');
      expect(n['leaveId'], sent.id);
      expect(n['message'], 'Mo Member submitted a leave request');
      expect(n['detail'], startsWith('Other leave · '));
    }
    expect(fakes.sink.docs.length, 2);
  });
}
