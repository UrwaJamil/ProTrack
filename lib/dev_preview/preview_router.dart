import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/choose_role_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/common/notifications_screen.dart';
import '../features/common/splash_screen.dart';
import '../features/leader/screens/analytics_screen.dart';
import '../features/leader/screens/calendar_screen.dart';
import '../features/leader/screens/leave_requests_screen.dart';
import '../features/leader/screens/team_members_screen.dart';
import '../features/member/screens/project_chat_screen.dart';
import '../features/member/screens/request_leave_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/projects/presentation/project_detail_screen.dart';
import '../features/projects/presentation/project_form_screen.dart';
import '../features/projects/presentation/projects_overview_screen.dart';
import '../features/tasks/presentation/my_tasks_screen.dart';
import '../features/tasks/presentation/need_help_screen.dart';
import '../features/tasks/presentation/task_activity_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/task_form_screen.dart';
import '../navigation/leader_shell.dart';
import '../navigation/member_shell.dart';
import 'preview_home_screen.dart';

const previewHomePath = '/';

/// The preview's own router: the real app's paths and screens (mirrors
/// `lib/routing/app_router.dart`, so in-screen navigation keeps working)
/// plus the screen list at `/`, and **no auth redirect**.
///
/// When a phase adds a route to `app_router.dart`, add it here too; the
/// smoke test in `test/dev_preview/` opens every catalog entry.
final previewRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: previewHomePath,
    routes: [
      GoRoute(
        path: previewHomePath,
        builder: (context, state) => const PreviewHomeScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/choose-role',
        builder: (context, state) => const ChooseRoleScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/leader/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/leader/projects/new',
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: '/leader/projects/:projectId',
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['projectId']!,
          adminView: true,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => ProjectFormScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
          GoRoute(
            path: 'tasks/new',
            builder: (context, state) =>
                TaskFormScreen(projectId: state.pathParameters['projectId']!),
          ),
          GoRoute(
            path: 'tasks/:taskId',
            builder: (context, state) => TaskDetailScreen(
              projectId: state.pathParameters['projectId']!,
              taskId: state.pathParameters['taskId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => TaskFormScreen(
                  projectId: state.pathParameters['projectId']!,
                  taskId: state.pathParameters['taskId']!,
                ),
              ),
              ..._taskActivityRoutes(),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/member/projects/:projectId',
        builder: (context, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['projectId']!),
        routes: [
          GoRoute(
            path: 'tasks/:taskId',
            builder: (context, state) => TaskDetailScreen(
              projectId: state.pathParameters['projectId']!,
              taskId: state.pathParameters['taskId']!,
            ),
            routes: _taskActivityRoutes(),
          ),
          GoRoute(
            path: 'chat',
            builder: (context, state) => ProjectChatScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            LeaderShell(navigationShell: navigationShell),
        branches: [
          _tab(
            '/leader/projects',
            const ProjectsOverviewScreen(adminView: true),
          ),
          _tab('/leader/team', const TeamMembersScreen()),
          _tab('/leader/calendar', const CalendarScreen()),
          _tab('/leader/leave', const LeaveRequestsScreen()),
          _tab('/leader/profile', const ProfileScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MemberShell(navigationShell: navigationShell),
        branches: [
          _tab(
            '/member/projects',
            const ProjectsOverviewScreen(adminView: false),
          ),
          _tab('/member/tasks', const MyTasksScreen()),
          _tab('/member/leave', const RequestLeaveScreen()),
          _tab('/member/profile', const ProfileScreen()),
        ],
      ),
    ],
  ),
);

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

/// Phase 4: Comments / History and Need Help under a task, on both
/// dashboards (same as `app_router.dart`).
List<GoRoute> _taskActivityRoutes() => [
  GoRoute(
    path: 'activity',
    builder: (context, state) => TaskActivityScreen(
      projectId: state.pathParameters['projectId']!,
      taskId: state.pathParameters['taskId']!,
    ),
  ),
  GoRoute(
    path: 'help',
    builder: (context, state) => NeedHelpScreen(
      projectId: state.pathParameters['projectId']!,
      taskId: state.pathParameters['taskId']!,
    ),
  ),
];
