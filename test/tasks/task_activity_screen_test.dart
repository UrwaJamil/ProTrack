import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/user_repository.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_activity_repository.dart';
import 'package:team_project_manager/features/tasks/data/help_note.dart';
import 'package:team_project_manager/features/tasks/data/task_comment.dart';
import 'package:team_project_manager/features/tasks/data/task_history_entry.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/need_help_screen.dart';
import 'package:team_project_manager/features/tasks/presentation/task_activity_screen.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/comment_composer.dart';

import '../support/fake_projects.dart';
import '../support/fake_task_activity.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

const _base = '/leader/projects/abcd1234/tasks/tid12345';

/// admin = Admin, member1 = assignee, member2 = Member not assigned.
final _project = testProject(
  members: {
    'admin': UserRole.leader,
    'member1': UserRole.member,
    'member2': UserRole.member,
  },
);

typedef _Fakes = ({
  FakeTaskRepository tasks,
  FakeTaskActivityRepository activity,
});

Future<_Fakes> _pump(
  WidgetTester tester, {
  required String uid,
  required String path,
  Project? project,
  List<TaskComment> comments = const [],
  bool blockedWithRequest = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tasks = FakeTaskRepository([
    testTask(
      status: blockedWithRequest ? TaskStatus.blocked : TaskStatus.inProgress,
    ),
    testTask(id: 'other', assignedTo: ['member2']),
  ]);
  final activity = FakeTaskActivityRepository(
    tasks,
    comments: {'abcd1234/tid12345': comments},
    // member1 asked member2 for help (request req1).
    history: {
      if (blockedWithRequest)
        'abcd1234/tid12345': [
          TaskHistoryEntry(
            id: 'req1',
            who: 'member1',
            action: HistoryAction.helpRequested,
            from: 'in_progress',
            to: 'member2',
            at: DateTime(2026, 10, 15, 9),
          ),
        ],
    },
    helpNotes: {
      if (blockedWithRequest)
        'abcd1234/tid12345': const HelpNote(
          text: 'Rules tests fail',
          taggedUserId: 'member2',
          requestId: 'req1',
        ),
    },
  );
  String param(GoRouterState s, String k) => s.pathParameters[k]!;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '$_base/activity'
            .replaceAll('abcd1234', ':id')
            .replaceAll('tid12345', ':taskId'),
        builder: (_, s) => TaskActivityScreen(
          projectId: param(s, 'id'),
          taskId: param(s, 'taskId'),
        ),
      ),
      GoRoute(
        path: '$_base/help'
            .replaceAll('abcd1234', ':id')
            .replaceAll('tid12345', ':taskId'),
        builder: (_, s) => NeedHelpScreen(
          projectId: param(s, 'id'),
          taskId: param(s, 'taskId'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([project ?? _project]),
        ),
        taskRepositoryProvider.overrideWithValue(tasks),
        taskActivityRepositoryProvider.overrideWithValue(activity),
        userRepositoryProvider.overrideWithValue(testUsers()),
        currentUidProvider.overrideWithValue(uid),
        todayProvider.overrideWithValue(DateTime(2026, 10, 15, 12)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push(path);
  await tester.pumpAndSettle();
  return (tasks: tasks, activity: activity);
}

final _comment = TaskComment(
  id: 'c1',
  authorId: 'member1',
  text: 'Uploaded the first variants.',
  createdAt: DateTime(2026, 10, 15, 9, 30),
);

void main() {
  group('Comments / History', () {
    testWidgets('lists comments with author, role badge and time', (
      tester,
    ) async {
      await _pump(
        tester,
        uid: 'member2',
        path: '$_base/activity',
        comments: [_comment],
      );
      expect(find.text('Design login screen'), findsOneWidget);
      expect(find.text('Comments (1)'), findsOneWidget);
      expect(find.text('Mo Member'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Today, 09:30 AM'), findsOneWidget);
      expect(find.text('Uploaded the first variants.'), findsOneWidget);
      // Not the author or an Admin: no edit/delete menu.
      expect(find.byTooltip('Comment options'), findsNothing);
      // Not the assignee: no help button.
      expect(find.text('Need help?'), findsNothing);
    });

    testWidgets('posting a comment adds it and clears the field', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member2',
        path: '$_base/activity',
      );
      expect(find.text('No comments yet'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  On it  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(fakes.activity.calls, ['addComment']);
      expect(find.text('On it'), findsOneWidget);
      expect(find.text('Comments (1)'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('a failed send keeps the text and shows an error', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member2',
        path: '$_base/activity',
      );
      fakes.activity.writeError = Exception('denied');
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't post the comment. Please try again."),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Hello');
    });

    testWidgets('an Admin can delete a Member\'s comment', (tester) async {
      await _pump(
        tester,
        uid: 'admin',
        path: '$_base/activity',
        comments: [_comment],
      );
      await tester.tap(find.byTooltip('Comment options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Uploaded the first variants.'), findsNothing);
      expect(find.text('No comments yet'), findsOneWidget);
    });

    testWidgets('no composer on an archived project', (tester) async {
      await _pump(
        tester,
        uid: 'member1',
        path: '$_base/activity',
        project: testProject(status: ProjectStatus.archived),
      );
      expect(find.byType(CommentComposer), findsNothing);
      expect(find.text('Need help?'), findsNothing);
    });

    testWidgets('History starts empty', (tester) async {
      await _pump(tester, uid: 'member1', path: '$_base/activity');
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
      expect(find.byType(CommentComposer), findsNothing);
    });
  });

  group('Need Help', () {
    testWidgets('the assignee requests help: Blocked, help note, history', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member1',
        path: '$_base/activity',
      );
      await tester.tap(find.text('Need help?'));
      await tester.pumpAndSettle();
      expect(find.text('Who can help?'), findsOneWidget);

      // Least busy first: Ada Admin (0 active) before Mia Member (1
      // active); never the requester (Mo Member).
      expect(find.text('Mo Member'), findsNothing);
      final ada = tester.getTopLeft(find.text('Ada Admin')).dy;
      final mia = tester.getTopLeft(find.text('Mia Member')).dy;
      expect(ada, lessThan(mia));
      expect(find.text('0 active tasks'), findsOneWidget);
      expect(find.text('1 active task'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, 'Request Help');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Rules tests fail');
      await tester.tap(find.text('Mia Member'));
      await tester.pump();
      expect(
        find.text('Mia Member will be notified with this task attached.'),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(fakes.activity.calls, ['requestHelp']);
      final task = fakes.tasks.tasks['abcd1234/tid12345']!;
      expect(task.status, TaskStatus.blocked);
      // Back on Comments / History, the note is visible to the team.
      expect(find.text('Help requested from Mia Member'), findsOneWidget);
      expect(find.text('Rules tests fail'), findsOneWidget);
      expect(find.text('Update help request'), findsOneWidget);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'requested help from Mia Member',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Member who is not assigned cannot ask', (tester) async {
      await _pump(tester, uid: 'member2', path: '$_base/help');
      expect(find.text("You can't ask for help on this task"), findsOneWidget);
    });
  });

  group('I can help', () {
    testWidgets('the named helper accepts: history + notification', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member2',
        path: '$_base/activity',
        blockedWithRequest: true,
      );
      expect(find.text('Help requested from Mia Member'), findsOneWidget);
      await tester.tap(find.text('I can help'));
      await tester.pumpAndSettle();

      expect(fakes.activity.calls, ['acceptHelp']);
      expect(find.text('I can help'), findsNothing);
      expect(find.text('You accepted this request'), findsOneWidget);
      expect(fakes.activity.notifications['help_accepted_req1'], {
        'userId': 'member1',
        'senderId': 'member2',
        'type': 'help_accepted',
        'projectId': 'abcd1234',
        'taskId': 'tid12345',
        'message': 'Mia Member accepted your help request',
        'read': false,
        'createdAt': isA<DateTime>(),
      });

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          "accepted Mo Member's help request",
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    for (final uid in ['member1', 'admin']) {
      testWidgets('not shown to $uid (not the named helper)', (tester) async {
        await _pump(
          tester,
          uid: uid,
          path: '$_base/activity',
          blockedWithRequest: true,
        );
        expect(find.text('Help requested from Mia Member'), findsOneWidget);
        expect(find.text('I can help'), findsNothing);
      });
    }

    testWidgets('a failed accept shows an error and keeps the button', (
      tester,
    ) async {
      final fakes = await _pump(
        tester,
        uid: 'member2',
        path: '$_base/activity',
        blockedWithRequest: true,
      );
      fakes.activity.writeError = Exception('denied');
      await tester.tap(find.text('I can help'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't accept the request. Please try again."),
        findsOneWidget,
      );
      expect(find.text('I can help'), findsOneWidget);
    });
  });
}
