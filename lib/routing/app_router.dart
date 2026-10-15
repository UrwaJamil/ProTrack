import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/app_user.dart';
import '../features/auth/presentation/choose_role_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/common/notifications_screen.dart';
import '../features/common/splash_screen.dart';
import '../features/leader/screens/analytics_screen.dart';
import '../features/leader/screens/calendar_screen.dart';
import '../features/leader/screens/leave_requests_screen.dart';
import '../features/leader/screens/task_detail_screen.dart' as leader;
import '../features/leader/screens/team_members_screen.dart';
import '../features/member/screens/my_tasks_screen.dart';
import '../features/member/screens/project_chat_screen.dart';
import '../features/member/screens/request_leave_screen.dart';
import '../features/member/screens/task_detail_screen.dart' as member;
import '../features/profile/presentation/profile_screen.dart';
import '../features/projects/presentation/project_detail_screen.dart';
import '../features/projects/presentation/project_form_screen.dart';
import '../features/projects/presentation/projects_overview_screen.dart';
import '../navigation/leader_shell.dart';
import '../navigation/member_shell.dart';
import 'router_refresh.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final target = authRedirect(auth, state.matchedLocation);
      authLog(
        'redirect: ${state.matchedLocation} -> ${target ?? '(stay)'} '
        '[status=${auth.status.name}, role=${auth.sessionRole?.value}]',
      );
      return target;
    },
    routes: [
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
      // Before '/leader/projects/:projectId' so "new" isn't read as an id.
      GoRoute(
        path: '/leader/projects/new',
        builder: (context, state) => const ProjectFormScreen(),
      ),
      GoRoute(
        path: '/leader/projects/:projectId',
        builder: (context, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['projectId']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => ProjectFormScreen(
              projectId: state.pathParameters['projectId']!,
            ),
          ),
          GoRoute(
            path: 'tasks/:taskId',
            builder: (context, state) => leader.TaskDetailScreen(
              projectId: state.pathParameters['projectId']!,
              taskId: state.pathParameters['taskId']!,
            ),
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
            builder: (context, state) => member.TaskDetailScreen(
              projectId: state.pathParameters['projectId']!,
              taskId: state.pathParameters['taskId']!,
            ),
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
  );
});

/// One bottom-nav / sidebar tab: a shell branch holding a single route.
StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

/// Pure auth gate behind [routerProvider]'s `redirect`; `null` means stay.
String? authRedirect(AuthState auth, String location) {
  final atSplash = location == '/splash';
  final atAuthScreen =
      location == '/login' ||
      location == '/register' ||
      location == '/forgot-password';
  final atChooseRole = location == '/choose-role';

  switch (auth.status) {
    // First Google sign-in: nothing else is reachable until a role is
    // picked (or the sign-up is cancelled).
    case AuthStatus.needsRole:
      return atChooseRole ? null : '/choose-role';

    // Signed-in-but-unresolved (or about to be signed out): hold on the
    // splash so no dashboard — or login — flashes in the meantime.
    case AuthStatus.loading:
    case AuthStatus.profileMissing:
      return atSplash ? null : '/splash';

    case AuthStatus.unauthenticated:
      return atAuthScreen ? null : '/login';

    case AuthStatus.authenticated:
      final home = switch (auth.sessionRole!) {
        UserRole.leader => '/leader/projects',
        UserRole.member => '/member/projects',
      };
      if (atAuthScreen || atSplash || atChooseRole) return home;
      if (auth.sessionRole == UserRole.leader &&
          location.startsWith('/member')) {
        return home;
      }
      if (auth.sessionRole == UserRole.member &&
          location.startsWith('/leader')) {
        return home;
      }
      return null;
  }
}
