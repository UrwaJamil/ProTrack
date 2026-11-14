import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/dev_preview/fakes/preview_notification_repository.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/common/notifications_screen.dart';
import 'package:team_project_manager/features/notifications/application/notification_center_providers.dart';
import 'package:team_project_manager/features/notifications/application/notification_providers.dart';
import 'package:team_project_manager/features/notifications/data/app_notification.dart';
import 'package:team_project_manager/features/notifications/data/notification_repository.dart';
import 'package:team_project_manager/features/notifications/data/notification_payloads.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';

import '../support/fake_projects.dart';
import '../support/project_fixtures.dart';

final _now = DateTime(2026, 11, 9, 10);

Map<String, dynamic> _at(
  Map<String, dynamic> data,
  Duration ago, {
  bool read = false,
}) => {...data, 'createdAt': _now.subtract(ago), 'read': read};

/// member1's notices: an unread comment (newest), an unread blocked
/// notice, a read leave decision; plus one for someone else.
Map<String, Map<String, dynamic>> _seed() => {
  commentNotificationId('c1', 'member1'): _at(
    commentNotification(
      recipient: 'member1',
      authorUid: 'admin',
      authorName: 'Ada Admin',
      taskTitle: 'Design login screen',
      text: 'Looks great',
      projectId: 'abcd1234',
      taskId: 'tid12345',
      commentId: 'c1',
    ),
    const Duration(minutes: 5),
  ),
  taskBlockedNotificationId('r1', 'member1'): _at(
    taskBlockedNotification(
      recipient: 'member1',
      requesterUid: 'member2',
      taskTitle: 'Rules',
      reason: 'Emulator down',
      projectId: 'abcd1234',
      taskId: 'tid12345',
    ),
    const Duration(hours: 2),
  ),
  'leave_l1': _at(
    {
      'userId': 'member1',
      'senderId': 'admin',
      'type': 'leave_approved',
      'projectId': 'abcd1234',
      'leaveId': 'l1',
      'message': 'Ada Admin approved your Casual leave (Nov 12)',
    },
    const Duration(days: 2),
    read: true,
  ),
  commentNotificationId('c2', 'admin'): _at(
    commentNotification(
      recipient: 'admin',
      authorUid: 'member1',
      authorName: 'Mo Member',
      taskTitle: 'X',
      text: 'Not for member1',
      projectId: 'abcd1234',
      taskId: 'tid12345',
      commentId: 'c2',
    ),
    const Duration(minutes: 1),
  ),
};

class _FailingRepo extends PreviewNotificationRepository {
  @override
  Stream<List<AppNotification>> watchMine(String uid) =>
      Stream.error(StateError('index missing'));
}

class _FailingMarkAll extends PreviewNotificationRepository {
  _FailingMarkAll(super.seed);

  @override
  Future<void> markAllRead(String uid) async => throw StateError('offline');
}

Future<GoRouter> _pump(
  WidgetTester tester,
  NotificationRepository repo, {
  UserRole role = UserRole.member,
}) async {
  tester.view.physicalSize = const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/:dash/projects/:id/tasks/:taskId/activity',
        builder: (_, s) => Scaffold(body: Text('Activity ${s.uri.path}')),
      ),
      GoRoute(
        path: '/member/leave/:id',
        builder: (_, s) => Text('Leave ${s.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([testProject()]),
        ),
        currentUidProvider.overrideWithValue('member1'),
        notificationRoleProvider.overrideWithValue(role),
        todayProvider.overrideWithValue(_now),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('lists my notices newest first with the unread chip', (
    tester,
  ) async {
    await _pump(tester, PreviewNotificationRepository(_seed()));
    expect(find.text('2 new'), findsOneWidget);
    expect(find.text('Not for member1'), findsNothing);

    final comment = find.text('Ada Admin commented on Design login screen');
    final blocked = find.text('Task Rules is blocked');
    final leave = find.text('Ada Admin approved your Casual leave (Nov 12)');
    expect(
      tester.getTopLeft(comment).dy,
      lessThan(tester.getTopLeft(blocked).dy),
    );
    expect(
      tester.getTopLeft(blocked).dy,
      lessThan(tester.getTopLeft(leave).dy),
    );
    // Comment quoted; others show project · detail; relative times.
    expect(find.text('“Looks great”'), findsOneWidget);
    expect(find.text('Mobile App Redesign · Emulator down'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
    expect(
      find.text("You're completely caught up with your team."),
      findsNothing,
    );
  });

  testWidgets('Mark all as read clears the chip and shows caught up', (
    tester,
  ) async {
    final repo = PreviewNotificationRepository(_seed());
    await _pump(tester, repo);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('2 new'), findsNothing);
    expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    expect(
      find.text("You're completely caught up with your team."),
      findsOneWidget,
    );
    // Only member1's notices.
    expect(repo.docs[commentNotificationId('c2', 'admin')]!['read'], isFalse);
    final button = find.widgetWithText(TextButton, 'Mark all as read');
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('a failed Mark all shows an error', (tester) async {
    await _pump(tester, _FailingMarkAll(_seed()));
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't update. Please try again."), findsOneWidget);
    expect(find.text('2 new'), findsOneWidget);
  });

  testWidgets('tapping marks read and opens the task (Member view)', (
    tester,
  ) async {
    final repo = PreviewNotificationRepository(_seed());
    await _pump(tester, repo);
    await tester.tap(find.text('Task Rules is blocked'));
    await tester.pumpAndSettle();
    expect(
      find.text('Activity /member/projects/abcd1234/tasks/tid12345/activity'),
      findsOneWidget,
    );
    expect(
      repo.docs[taskBlockedNotificationId('r1', 'member1')]!['read'],
      true,
    );
  });

  testWidgets('a leave decision opens the request', (tester) async {
    await _pump(tester, PreviewNotificationRepository(_seed()));
    await tester.tap(
      find.text('Ada Admin approved your Casual leave (Nov 12)'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave l1'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, PreviewNotificationRepository());
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('error state with Retry', (tester) async {
    await _pump(tester, _FailingRepo());
    expect(find.text("We couldn't load your notifications."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  test('the bell count follows unread notices', () async {
    final repo = PreviewNotificationRepository(_seed());
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWithValue('member1'),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(unreadNotificationCountProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(myUnreadCountProvider.future);
    expect(container.read(unreadNotificationCountProvider), 2);
    await repo.markAllRead('member1');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadNotificationCountProvider), 0);
  });
}
