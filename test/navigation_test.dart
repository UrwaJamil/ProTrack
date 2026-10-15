import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/application/auth_controller.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/navigation/leader_shell.dart';
import 'package:team_project_manager/navigation/member_shell.dart';
import 'package:team_project_manager/routing/app_router.dart';

import 'support/fake_auth.dart';

AuthState _signedIn(UserRole role) => AuthState.authenticated(
  user: FakeUser('u'),
  profile: AppUser(
    uid: 'u',
    name: 'U',
    email: 'u@example.com',
    defaultRole: role,
    skillTags: const [],
    createdAt: DateTime(2026),
  ),
);

void main() {
  test('Admin tabs: Projects, Team, Calendar, Leave, Profile', () {
    expect(leaderDestinations.map((d) => d.label), [
      'Projects',
      'Team',
      'Calendar',
      'Leave',
      'Profile',
    ]);
  });

  test('Member tabs: Projects, My Tasks, Leave, Profile', () {
    expect(memberDestinations.map((d) => d.label), [
      'Projects',
      'My Tasks',
      'Leave',
      'Profile',
    ]);
  });

  test('Members land on their Projects tab', () {
    expect(
      authRedirect(_signedIn(UserRole.member), '/splash'),
      '/member/projects',
    );
  });

  test('the bell and Analytics pages are reachable outside the tabs', () {
    expect(authRedirect(_signedIn(UserRole.member), '/notifications'), isNull);
    expect(authRedirect(_signedIn(UserRole.leader), '/notifications'), isNull);
    expect(
      authRedirect(_signedIn(UserRole.leader), '/leader/analytics'),
      isNull,
    );
    // Analytics is Admin-only, like every /leader route.
    expect(
      authRedirect(_signedIn(UserRole.member), '/leader/analytics'),
      '/member/projects',
    );
  });

  test('creating a project is Admin-dashboard only', () {
    expect(
      authRedirect(_signedIn(UserRole.member), '/leader/projects/new'),
      '/member/projects',
    );
  });
}
