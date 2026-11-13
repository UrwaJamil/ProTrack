import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/core/widgets/on_leave_badge.dart';
import 'package:team_project_manager/dev_preview/fakes/preview_leave_repository.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/leave/application/leave_validation.dart';
import 'package:team_project_manager/features/leave/data/leave_repository.dart';
import 'package:team_project_manager/features/leave/data/leave_request.dart';
import 'package:team_project_manager/features/leave/data/leave_settings.dart';
import 'package:team_project_manager/features/leave/data/leave_type.dart';
import 'package:team_project_manager/features/leave/presentation/leave_detail_screen.dart';
import 'package:team_project_manager/features/leave/presentation/leave_management_body.dart';
import 'package:team_project_manager/features/leave/presentation/leave_overview_body.dart';
import 'package:team_project_manager/features/leave/presentation/leave_request_form_screen.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/application/task_activity_providers.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/team/presentation/member_profile_screen.dart';
import 'package:team_project_manager/features/team/presentation/team_body.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

/// admin leads the project; member1 and member2 are Members.
final _project = testProject(
  members: {
    'admin': UserRole.leader,
    'member1': UserRole.member,
    'member2': UserRole.member,
  },
);

/// Monday, Nov 9 2026.
final _today = DateTime(2026, 11, 9, 10);

LeaveRequest _request({
  String id = 'l1',
  String userId = 'member1',
  LeaveStatus status = LeaveStatus.pending,
  DateTime? from,
  DateTime? to,
  String? decidedBy,
}) => LeaveRequest(
  id: id,
  userId: userId,
  type: LeaveType.casual,
  fromDate: from ?? DateTime(2026, 11, 12),
  toDate: to ?? DateTime(2026, 11, 13),
  halfDay: false,
  reason: 'Family event',
  workingDays: 2,
  status: status,
  approverIds: const ['admin'],
  createdAt: DateTime(2026, 11, 2),
  decidedBy: decidedBy,
  decidedVia: decidedBy == null ? null : 'abcd1234',
  decidedAt: decidedBy == null ? null : DateTime(2026, 11, 3),
);

typedef _Fakes = ({
  PreviewLeaveRepository leave,
  FakeProjectRepository projects,
  GoRouter router,
});

Future<_Fakes> _pump(
  WidgetTester tester, {
  required String uid,
  required String path,
  List<LeaveRequest> requests = const [],
  LeaveSettings settings = LeaveSettings.defaults,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final leave = PreviewLeaveRepository(requests: requests, settings: settings);
  final projects = FakeProjectRepository([
    _project,
    testProject(
      id: 'other123',
      name: 'Second Project',
      members: {'admin': UserRole.leader},
    ),
  ]);
  final tasks = FakeTaskRepository([
    testTask(assignedTo: ['member1'], deadline: DateTime(2026, 11, 12)),
    testTask(
      id: 't2',
      title: 'Second task',
      assignedTo: ['member1', 'member2'],
    ),
  ]);
  final users = testUsers();
  users.docs['member1'] = {
    ...users.docs['member1']!,
    'skillTags': ['Flutter', 'Firebase'],
  };
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/member/leave',
        builder: (_, _) => const Scaffold(body: LeaveOverviewBody()),
      ),
      GoRoute(
        path: '/member/leave/new',
        builder: (_, _) => const LeaveRequestFormScreen(),
      ),
      GoRoute(
        path: '/member/leave/:id',
        builder: (_, s) => LeaveDetailScreen(leaveId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leader/leave',
        builder: (_, _) => const Scaffold(body: LeaveManagementBody()),
      ),
      GoRoute(
        path: '/leader/team',
        builder: (_, _) => const Scaffold(body: TeamBody()),
      ),
      GoRoute(
        path: '/leader/team/:uid',
        builder: (_, s) => MemberProfileScreen(uid: s.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/leader/projects/:id/tasks/:taskId',
        builder: (_, _) => const Scaffold(body: Text('Task detail')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(projects),
        taskRepositoryProvider.overrideWithValue(tasks),
        userRepositoryProvider.overrideWithValue(users),
        leaveRepositoryProvider.overrideWithValue(leave),
        currentUidProvider.overrideWithValue(uid),
        todayProvider.overrideWithValue(_today),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push(path);
  await tester.pumpAndSettle();
  return (leave: leave, projects: projects, router: router);
}

/// Opens the [hint] date field's picker and picks [day] of the month it
/// opens on.
Future<void> _pickDay(WidgetTester tester, String hint, String day) async {
  await tester.tap(find.widgetWithText(TextFormField, hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(day).first);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('Member Leave tab', () {
    testWidgets('stat tiles and my requests, newest first', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        uid: 'member1',
        path: '/member/leave',
        requests: [
          _request(
            id: 'old',
            status: LeaveStatus.approved,
            decidedBy: 'admin',
            from: DateTime(2026, 10, 22),
            to: DateTime(2026, 10, 23),
          ),
          _request(),
          _request(id: 'theirs', userId: 'member2'),
        ],
      );
      // Used 2 · Remaining (10-2)+8+3 = 19 · Pending 2.
      expect(find.bySemanticsLabel('Used: 2 days'), findsOneWidget);
      expect(find.bySemanticsLabel('Remaining: 19 days'), findsOneWidget);
      expect(find.bySemanticsLabel('Pending: 2 days'), findsOneWidget);
      expect(find.text('2 total'), findsOneWidget);
      final pending = tester.getTopLeft(find.text('Nov 12 – Nov 13, 2026')).dy;
      final old = tester.getTopLeft(find.text('Oct 22 – Oct 23, 2026')).dy;
      expect(pending, lessThan(old));
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Approved'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('empty state', (tester) async {
      await _pump(tester, uid: 'member1', path: '/member/leave');
      expect(find.text('No leave requests yet'), findsOneWidget);
    });
  });

  group('Request Leave', () {
    testWidgets('no approver: blocked with the message', (tester) async {
      // admin is the only leader of their projects: nobody approves them.
      await _pump(tester, uid: 'admin', path: '/member/leave/new');
      expect(find.text(noApproverMessage), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Submit Request');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('over balance is blocked; Other is never blocked', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member1',
        path: '/member/leave/new',
        settings: const LeaveSettings(allowances: {LeaveType.casual: 0}),
      );
      expect(find.text('Available Casual Leave'), findsOneWidget);
      // The 1st to the 28th of any month has working days.
      await _pickDay(tester, 'Start', '1');
      await _pickDay(tester, 'End', '28');
      expect(find.textContaining('Only 0 Casual days'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Submit Request');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only 0'), findsNothing);
      expect(find.text('No yearly limit'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'Conference');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      final sent = fakes.leave.requests.values.single;
      expect(sent.userId, 'member1');
      expect(sent.type, LeaveType.other);
      expect(sent.approverIds, ['admin']);
      expect(sent.status, LeaveStatus.pending);
      expect(sent.reason, 'Conference');
      expect(find.text('Leave request sent for approval.'), findsOneWidget);
    });

    testWidgets('a reason is required', (tester) async {
      final fakes = await _pump(
        tester,
        uid: 'member1',
        path: '/member/leave/new',
      );
      await _pickDay(tester, 'Start', '1');
      await _pickDay(tester, 'End', '28');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Submit Request');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Please add a reason.'), findsOneWidget);
      expect(fakes.leave.requests, isEmpty);
    });
  });

  group('Leave detail', () {
    testWidgets('cancel while pending deletes the request', (tester) async {
      final fakes = await _pump(
        tester,
        uid: 'member1',
        path: '/member/leave/l1',
        requests: [_request()],
      );
      expect(find.text('Family event'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel request'));
      await tester.pumpAndSettle();
      expect(fakes.leave.requests, isEmpty);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('no cancel once decided; shows who decided', (tester) async {
      await _pump(
        tester,
        uid: 'member1',
        path: '/member/leave/l1',
        requests: [_request(status: LeaveStatus.approved, decidedBy: 'admin')],
      );
      expect(find.text('Cancel request'), findsNothing);
      expect(find.text('by Ada Admin on Nov 3, 2026'), findsOneWidget);
    });

    testWidgets('a cancelled request shows not found', (tester) async {
      await _pump(tester, uid: 'member1', path: '/member/leave/gone');
      expect(find.text('Request not found'), findsOneWidget);
    });
  });

  group('Leave Management', () {
    testWidgets('approve: decided, leaveDays written, requester notified', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'admin',
        path: '/leader/leave',
        requests: [_request()],
      );
      expect(find.text('1 Pending'), findsOneWidget);
      expect(find.text('Mo Member'), findsOneWidget);
      expect(find.text('“Family event”'), findsOneWidget);
      // member1's task is due on Nov 12, inside the leave.
      expect(
        find.text("1 of Mo Member's task is due during this leave"),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      final decided = fakes.leave.requests['l1']!;
      expect(decided.status, LeaveStatus.approved);
      expect(decided.decidedBy, 'admin');
      expect(decided.decidedVia, 'abcd1234');
      final notice = fakes.leave.notifications['leave_l1']!;
      expect(notice['type'], 'leave_approved');
      expect(notice['userId'], 'member1');
      expect(notice['message'], startsWith('Ada Admin approved your Casual'));
      expect(find.text('No pending requests'), findsOneWidget);

      await tester.tap(find.text('History (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Approved'), findsOneWidget);
      expect(find.textContaining('by Ada Admin'), findsOneWidget);
    });

    testWidgets('reject: no leaveDays', (tester) async {
      final fakes = await _pump(
        tester,
        uid: 'admin',
        path: '/leader/leave',
        requests: [_request()],
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(fakes.leave.requests['l1']!.status, LeaveStatus.rejected);
      expect(fakes.leave.notifications['leave_l1']!['type'], 'leave_rejected');
      // Outside fake async, or the stream's first event never arrives.
      final current = await tester.runAsync(
        () => fakes.leave.watchCurrentLeave(_today).first,
      );
      expect(current, isEmpty);
    });

    testWidgets('empty states', (tester) async {
      await _pump(tester, uid: 'admin', path: '/leader/leave');
      expect(find.text('No pending requests'), findsOneWidget);
      await tester.tap(find.text('History (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No decisions yet'), findsOneWidget);
    });
  });

  group('Team', () {
    final onLeaveToday = _request(
      id: 'now',
      userId: 'member2',
      status: LeaveStatus.approved,
      decidedBy: 'admin',
      from: DateTime(2026, 11, 9),
      to: DateTime(2026, 11, 10),
    );

    testWidgets('members with active tasks and On Leave; search filters', (
      tester,
    ) async {
      await _pump(
        tester,
        uid: 'admin',
        path: '/leader/team',
        requests: [onLeaveToday],
      );
      expect(find.text('Mo Member'), findsOneWidget);
      expect(find.text('Mia Member'), findsOneWidget);
      expect(find.text('Ada Admin'), findsNothing);
      expect(find.text('2 active tasks'), findsOneWidget);
      expect(find.text('1 active task'), findsOneWidget);
      expect(find.byType(OnLeaveBadge), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'mia');
      await tester.pumpAndSettle();
      expect(find.text('Mo Member'), findsNothing);
      expect(find.text('Mia Member'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('member profile: skills, tasks, add to project', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'admin',
        path: '/leader/team/member1',
      );
      expect(find.text('Mo Member'), findsOneWidget);
      expect(find.text('member1@example.com'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(find.text('Second task'), findsOneWidget);
      expect(find.byType(OnLeaveBadge), findsNothing);

      await tester.tap(find.text('Add to project'));
      await tester.pumpAndSettle();
      expect(find.text('Second Project'), findsOneWidget);
      await tester.tap(find.text('Second Project'));
      await tester.pumpAndSettle();
      expect(fakes.projects.calls, contains('addMember:member1'));
      expect(
        fakes.projects.projects['other123']!.members['member1'],
        UserRole.member,
      );
      expect(find.text('Mo Member added to Second Project.'), findsOneWidget);
    });

    testWidgets('member profile shows On Leave', (tester) async {
      await _pump(
        tester,
        uid: 'admin',
        path: '/leader/team/member2',
        requests: [onLeaveToday],
      );
      expect(find.byType(OnLeaveBadge), findsOneWidget);
    });
  });

  test('"Who can help?" leaves out people on approved leave today', () async {
    final leave = PreviewLeaveRepository(
      requests: [
        _request(
          id: 'now',
          userId: 'member2',
          status: LeaveStatus.approved,
          decidedBy: 'admin',
          from: DateTime(2026, 11, 9),
          to: DateTime(2026, 11, 9),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([_project]),
        ),
        taskRepositoryProvider.overrideWithValue(
          FakeTaskRepository([testTask()]),
        ),
        userRepositoryProvider.overrideWithValue(testUsers()),
        leaveRepositoryProvider.overrideWithValue(leave),
        currentUidProvider.overrideWithValue('member1'),
        todayProvider.overrideWithValue(_today),
      ],
    );
    addTearDown(container.dispose);
    const key = (projectId: 'abcd1234', taskId: 'tid12345');
    final sub = container.listen(helperCandidatesProvider(key), (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 20 && !sub.read().hasValue; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // Let the leave stream deliver too.
    await Future<void>.delayed(Duration.zero);
    final helpers = container.read(helperCandidatesProvider(key)).value!;
    expect(helpers.map((h) => h.user.uid), ['admin']);
  });
}
