// Visual check of the existing screens: renders them at 390x884 with Roboto
// (the default Material font, from the Flutter SDK) and saves PNGs to
// build/visual/ (git-ignored) for comparison with design/screens/.
// Skipped by a plain `flutter test`; run with:
//   flutter test test/visual --run-skipped --concurrency=1
@Skip('Visual screenshot script; run with --run-skipped')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/notifications/application/notification_providers.dart';
import 'package:team_project_manager/features/profile/presentation/profile_screen.dart';
import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/projects/presentation/projects_overview_screen.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';
import 'package:team_project_manager/features/tasks/presentation/my_tasks_screen.dart';
import 'package:team_project_manager/navigation/adaptive_shell.dart';
import 'package:team_project_manager/navigation/leader_shell.dart';
import 'package:team_project_manager/navigation/member_shell.dart';
import 'package:team_project_manager/navigation/protrack_app_bar.dart';

import '../support/fake_auth.dart';
import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/people.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

const _outDir = 'build/visual';
const _frame = Size(390, 884);
final _shotKey = GlobalKey();

// ---------------------------------------------------------------- fonts

Future<void> _loadFonts() async {
  ByteData bytes(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());

  final fonts = _materialFontsDir();
  final roboto = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    roboto.addFont(Future.value(bytes('$fonts/roboto-$weight.ttf')));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(bytes('$fonts/materialicons-regular.otf')));
  await icons.load();
}

/// Roboto and the Material icon font ship with the Flutter SDK. Found via
/// FLUTTER_ROOT, or from flutter_tester's own location
/// (`<sdk>/bin/cache/artifacts/engine/<platform>/flutter_tester`).
String _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final artifacts = root != null
      ? '$root/bin/cache/artifacts'
      : File(Platform.resolvedExecutable).parent.parent.parent.path;
  final dir = Directory('$artifacts/material_fonts');
  if (dir.existsSync()) return dir.path;
  throw StateError('Material fonts not found under $artifacts');
}

// ------------------------------------------------------------- fixtures

FakeUserRepository _users() {
  final users = testUsers();
  users.docs['member1'] = AppUser(
    uid: 'member1',
    name: 'Ayesha Noor',
    email: 'ayesha.noor@protrack.io',
    defaultRole: UserRole.member,
    skillTags: const ['Flutter', 'Firebase', 'UI Design', 'REST APIs'],
    createdAt: DateTime(2026),
  ).toMap();
  users.docs['admin'] = AppUser(
    uid: 'admin',
    name: 'Tariq Khan',
    email: 'tariq.khan@protrack.io',
    defaultRole: UserRole.leader,
    skillTags: const ['Architecture', 'Backend'],
    createdAt: DateTime(2026),
  ).toMap();
  return users;
}

final _today = DateTime(2026, 10, 15);

FakeTaskRepository _tasks() => FakeTaskRepository([
  testTask(id: 't1', title: 'Write API spec', status: TaskStatus.todo),
  testTask(id: 't2', title: 'Design login flow', status: TaskStatus.inProgress),
  testTask(
    id: 't3',
    title: 'Password reset wireframes',
    status: TaskStatus.onHold,
  ),
  testTask(
    id: 't4',
    title: 'Set up Firestore rules',
    status: TaskStatus.blocked,
  ),
  testTask(
    id: 't5',
    title: 'Fix navigation bar bug',
    status: TaskStatus.completed,
  ),
  testTask(
    id: 't6',
    title: 'Review database schema',
    status: TaskStatus.inProgress,
    deadline: DateTime(2026, 10, 10),
  ),
]);

// -------------------------------------------------------------- harness

/// Pumps [build] for a signed-in [uid] in [mode], sized like the mocks.
Future<void> _pump(
  WidgetTester tester, {
  required String uid,
  required ThemeMode mode,
  required Widget home,
  Size frame = _frame,
}) async {
  // The theme menu reads the stored mode, so store the one shown.
  SharedPreferences.setMockInitialValues({'theme_mode': mode.name});
  tester.view.physicalSize = frame;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository();
  final users = _users();
  final theme = AppTheme.lightTheme;
  final darkTheme = AppTheme.darkTheme;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeAuthOverrides(auth: auth, users: users),
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository([
            testProject(id: 'abcd1234', name: 'Mobile App v2'),
            testProject(id: 'efgh5678', name: 'Cloud Migration'),
          ]),
        ),
        taskRepositoryProvider.overrideWithValue(_tasks()),
        todayProvider.overrideWithValue(_today),
        unreadNotificationCountProvider.overrideWithValue(2),
      ],
      child: RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: home,
        ),
      ),
    ),
  );
  auth.restoreSession(uid);
  await tester.pumpAndSettle();
}

Widget _memberShell(int index, Widget body) => AdaptiveShell(
  appBar: const ProTrackAppBar(profileLocation: '/member/profile'),
  destinations: memberDestinations,
  selectedIndex: index,
  onDestinationSelected: (_) {},
  body: body,
);

Widget _leaderShell(int index, Widget body) => AdaptiveShell(
  appBar: const ProTrackAppBar(profileLocation: '/leader/profile'),
  destinations: leaderDestinations,
  selectedIndex: index,
  onDestinationSelected: (_) {},
  body: body,
);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

// ---------------------------------------------------------------- shots

void main() {
  setUpAll(_loadFonts);

  for (final (label, mode) in [
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    testWidgets('profile_member_$label', (tester) async {
      await _pump(
        tester,
        uid: 'member1',
        mode: mode,
        home: _memberShell(3, const ProfileScreen()),
      );
      await _shot(tester, 'profile_member_$label');
    });

    testWidgets('profile_admin_$label', (tester) async {
      await _pump(
        tester,
        uid: 'admin',
        mode: mode,
        home: _leaderShell(4, const ProfileScreen()),
      );
      await _shot(tester, 'profile_admin_$label');
    });

    testWidgets('projects_member_$label', (tester) async {
      await _pump(
        tester,
        uid: 'member1',
        mode: mode,
        home: _memberShell(0, const ProjectsOverviewScreen(adminView: false)),
      );
      await _shot(tester, 'projects_member_$label');
    });

    testWidgets('task_statuses_$label', (tester) async {
      await _pump(
        tester,
        uid: 'member1',
        mode: mode,
        // Taller than the phone frame so every status pill fits on one shot.
        frame: const Size(390, 1240),
        home: _memberShell(1, const MyTasksScreen()),
      );
      await _shot(tester, 'task_statuses_$label');
    });
  }
}
