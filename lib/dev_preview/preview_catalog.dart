import '../features/auth/data/app_user.dart';
import '../features/tasks/presentation/task_paths.dart';
import 'mock/mock_projects.dart';
import 'mock/mock_tasks.dart';

enum PreviewSection {
  admin('Admin', UserRole.leader),
  member('Member', UserRole.member),
  auth('Auth & onboarding', null);

  const PreviewSection(this.label, this.role);

  final String label;

  /// The session the screen is opened with; `null` keeps the current one.
  final UserRole? role;
}

/// One screen on the preview's start page.
class PreviewEntry {
  const PreviewEntry(
    this.title,
    this.path, {
    required this.section,
    required this.phase,
    this.note,
    this.tab = false,
  });

  final String title;

  /// A path in `preview_router.dart` (the same paths as the real app).
  final String path;
  final PreviewSection section;

  /// Where the screen stands, e.g. "Phase 3", "Placeholder → Phase 6".
  final String phase;
  final String? note;

  /// Shell tabs are opened with `go` (bottom nav works, no back arrow);
  /// everything else is pushed so its back arrow returns here.
  final bool tab;
}

const _mobile = MockProjects.mobileApp;
const _login = MockTasks.designLogin;

/// Every screen, both roles. **Each phase adds its new screens here** (and
/// their routes to `preview_router.dart`).
final previewEntries = <PreviewEntry>[
  // ------------------------------------------------------------- Admin
  ..._admin([
    ('Projects', '/leader/projects', 'Phase 2', null, true),
    ('Team', '/leader/team', 'Placeholder → Phase 6', null, true),
    ('Calendar', '/leader/calendar', 'Placeholder → Phase 7', null, true),
    ('Leave', '/leader/leave', 'Placeholder → Phase 6', null, true),
    ('Profile', '/leader/profile', 'Phase 1', null, true),
    ('Analytics', '/leader/analytics', 'Placeholder → Phase 9', null, false),
    ('New project', '/leader/projects/new', 'Phase 2', null, false),
    (
      'Project detail',
      '/leader/projects/$_mobile',
      'Phase 2',
      'Mobile App v2 (Admin)',
      false,
    ),
    (
      'Project detail: overdue',
      '/leader/projects/${MockProjects.designSystem}',
      'Phase 2',
      'Design System',
      false,
    ),
    (
      'Project detail: archived',
      '/leader/projects/${MockProjects.legacy}',
      'Phase 2',
      'Legacy Portal',
      false,
    ),
    (
      'Project detail: Admin as Member',
      '/leader/projects/${MockProjects.phoenix}',
      'Phase 2',
      'Project Phoenix, read-only (led by Hamza)',
      false,
    ),
    ('Edit project', '/leader/projects/$_mobile/edit', 'Phase 2', null, false),
    ('New task', newTaskPath(_mobile), 'Phase 3', null, false),
    (
      'Task detail',
      taskDetailPath(_mobile, _login, adminView: true),
      'Phase 3',
      'Design login flow',
      false,
    ),
    (
      'Task detail: overdue',
      taskDetailPath(
        MockProjects.cloudMigration,
        MockTasks.firestoreRules,
        adminView: true,
      ),
      'Phase 3',
      'Set up Firestore security rules',
      false,
    ),
    ('Edit task', editTaskPath(_mobile, _login), 'Phase 3', null, false),
    ('Notifications', '/notifications', 'Placeholder → Phase 8', null, false),
  ]),

  // ------------------------------------------------------------ Member
  ..._member([
    ('Projects', '/member/projects', 'Phase 2', null, true),
    ('My Tasks', '/member/tasks', 'Phase 3', null, true),
    ('Leave', '/member/leave', 'Placeholder → Phase 6', null, true),
    ('Profile', '/member/profile', 'Phase 1', null, true),
    (
      'Project detail',
      '/member/projects/$_mobile',
      'Phase 2',
      'Mobile App v2',
      false,
    ),
    (
      'Task detail',
      taskDetailPath(_mobile, _login, adminView: false),
      'Phase 3',
      'Design login flow (assignee)',
      false,
    ),
    (
      'Project chat',
      '/member/projects/$_mobile/chat',
      'Placeholder → Phase 5',
      null,
      false,
    ),
    ('Notifications', '/notifications', 'Placeholder → Phase 8', null, false),
  ]),

  // -------------------------------------------------------------- Auth
  ..._auth([
    ('Login', '/login', 'Phase 1'),
    ('Register', '/register', 'Phase 1'),
    ('Forgot password', '/forgot-password', 'Phase 1'),
    ('Choose role (first Google sign-in)', '/choose-role', 'Phase 1'),
    ('Splash', '/splash', 'Phase 1'),
  ]),
];

typedef _Row = (
  String title,
  String path,
  String phase,
  String? note,
  bool tab,
);

Iterable<PreviewEntry> _admin(List<_Row> rows) =>
    _rows(rows, PreviewSection.admin);

Iterable<PreviewEntry> _member(List<_Row> rows) =>
    _rows(rows, PreviewSection.member);

Iterable<PreviewEntry> _rows(List<_Row> rows, PreviewSection section) => [
  for (final (title, path, phase, note, tab) in rows)
    PreviewEntry(
      title,
      path,
      section: section,
      phase: phase,
      note: note,
      tab: tab,
    ),
];

Iterable<PreviewEntry> _auth(List<(String, String, String)> rows) => [
  for (final (title, path, phase) in rows)
    PreviewEntry(
      title,
      path,
      section: PreviewSection.auth,
      phase: phase,
      note: 'Shown while signed in; submitting has no redirect here',
    ),
];
