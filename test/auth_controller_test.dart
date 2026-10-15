import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/application/auth_controller.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/routing/app_router.dart';

import 'support/fake_auth.dart';

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: fakeAuthOverrides(auth: auth, users: users),
    );
    container.listen<AuthState>(
      authControllerProvider,
      (_, next) => history.add(next),
      fireImmediately: true,
    );
  }

  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  late final ProviderContainer container;
  final history = <AuthState>[];

  AuthController get controller =>
      container.read(authControllerProvider.notifier);
  AuthState get state => container.read(authControllerProvider);

  /// Where the router would send someone sitting on [from] for every state
  /// the controller passed through, in order.
  List<String?> redirectsFrom(String from) => [
    for (final s in history) authRedirect(s, from),
  ];

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void dispose() => container.dispose();
}

Future<_Harness> _signedOutHarness() async {
  final h = _Harness();
  h.auth.emitInitial();
  await h.settle();
  h.history.clear();
  return h;
}

void main() {
  group('UserRole.fromValue', () {
    test('accepts exactly "leader" and "member"', () {
      expect(UserRole.fromValue('leader'), UserRole.leader);
      expect(UserRole.fromValue('member'), UserRole.member);
      expect(UserRole.leader.value, 'leader');
      expect(UserRole.member.value, 'member');
    });

    test('rejects anything else instead of coercing it to member', () {
      for (final bad in [null, '', 'pm', 'pl', 'Leader', 'admin']) {
        expect(() => UserRole.fromValue(bad), throwsFormatException);
      }
    });
  });

  group('register', () {
    for (final role in UserRole.values) {
      test('writes defaultRole "${role.value}" and lands straight on its '
          'dashboard', () async {
        final h = await _signedOutHarness();
        addTearDown(h.dispose);

        await h.controller.register(
          name: 'Test',
          email: '${role.value}@example.com',
          password: 'password123',
          defaultRole: role,
        );
        await h.settle();

        final uid = h.auth.accounts['${role.value}@example.com']!.uid;
        expect(h.users.docs[uid]!['defaultRole'], role.value);
        expect(h.state.status, AuthStatus.authenticated);
        expect(h.state.sessionRole, role);

        // The register screen never redirects anywhere but this role's
        // dashboard — no intermediate stop at the other one or the splash.
        final home = role == UserRole.leader
            ? '/leader/projects'
            : '/member/projects';
        expect(h.redirectsFrom('/register').whereType<String>().toList(), [
          home,
        ]);
        // Only one profile resolution path: register() itself, never the
        // auth listener (no loading state while registering).
        expect(h.history.map((s) => s.status), [AuthStatus.authenticated]);
      });
    }

    test('rolls back the Auth user when users.create fails', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.users.failCreate = true;

      await expectLater(
        h.controller.register(
          name: 'Test',
          email: 'x@example.com',
          password: 'password123',
          defaultRole: UserRole.leader,
        ),
        throwsA(
          isA<AuthFlowException>().having(
            (e) => e.message,
            'message',
            registrationFailedMessage,
          ),
        ),
      );
      await h.settle();

      expect(h.auth.calls, contains('deleteUser'));
      expect(h.auth.accounts, isEmpty);
      expect(h.auth.currentUser, isNull);
      expect(h.users.docs, isEmpty);
      expect(h.state.status, AuthStatus.unauthenticated);
      expect(
        h.history.map((s) => s.status),
        isNot(contains(AuthStatus.authenticated)),
      );
    });

    test('falls back to signOut when deleting the Auth user fails', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.users.failCreate = true;
      h.auth.failDelete = true;

      await expectLater(
        h.controller.register(
          name: 'Test',
          email: 'x@example.com',
          password: 'password123',
          defaultRole: UserRole.member,
        ),
        throwsA(isA<AuthFlowException>()),
      );
      await h.settle();

      expect(h.auth.calls, containsAllInOrder(['deleteUser', 'signOut']));
      expect(h.auth.currentUser, isNull);
      expect(h.state.status, AuthStatus.unauthenticated);
    });
  });

  group('login', () {
    Future<_Harness> withAccounts() async {
      final h = await _signedOutHarness();
      for (final role in UserRole.values) {
        await h.controller.register(
          name: role.label,
          email: '${role.value}@example.com',
          password: 'password123',
          defaultRole: role,
        );
        await h.controller.signOut();
      }
      await h.settle();
      h.history.clear();
      return h;
    }

    for (final role in UserRole.values) {
      test('after logout, ${role.value} lands on its stored role', () async {
        final h = await withAccounts();
        addTearDown(h.dispose);

        await h.controller.login(
          email: '${role.value}@example.com',
          password: 'password123',
        );
        await h.settle();

        expect(h.state.status, AuthStatus.authenticated);
        expect(h.state.sessionRole, role);
        final home = role == UserRole.leader
            ? '/leader/projects'
            : '/member/projects';
        // /login -> /splash while loading -> home; never the other dashboard.
        expect(h.redirectsFrom('/login').whereType<String>().toSet(), {
          '/splash',
          home,
        });
      });
    }

    test('no users/{uid} doc: signs out with the setup message and never '
        'authenticates', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.accounts['orphan@example.com'] = (
        password: 'password123',
        uid: 'orphan',
      );

      await h.controller.login(
        email: 'orphan@example.com',
        password: 'password123',
      );
      await h.settle();

      expect(h.auth.calls, contains('signOut'));
      expect(h.auth.currentUser, isNull);
      expect(h.state.status, AuthStatus.unauthenticated);
      expect(h.state.message, accountSetupIncompleteMessage);
      expect(
        h.history.map((s) => s.status),
        contains(AuthStatus.profileMissing),
      );
      expect(h.history.any((s) => s.sessionRole != null), isFalse);
      expect(h.redirectsFrom('/login').whereType<String>().toSet(), {
        '/splash',
      });
    });

    test('a stored role other than "leader"/"member" is never coerced into '
        'a role', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.accounts['old@example.com'] = (password: 'p', uid: 'old');
      h.users.docs['old'] = {
        'name': 'Old',
        'email': 'old@example.com',
        'defaultRole': 'pm',
      };

      await h.controller.login(email: 'old@example.com', password: 'p');
      await h.settle();

      expect(h.state.status, AuthStatus.unauthenticated);
      expect(h.state.message, profileLoadFailedMessage);
      expect(h.history.any((s) => s.sessionRole != null), isFalse);
    });
  });

  test(
    'restored session without a profile doc is signed out on start',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.auth.restoreSession('orphan');
      await h.settle();

      expect(h.state.status, AuthStatus.unauthenticated);
      expect(h.state.message, accountSetupIncompleteMessage);
      expect(h.auth.currentUser, isNull);
    },
  );

  group('Google sign-in', () {
    const email = 'gina@gmail.com';

    test('first sign-in holds on the role picker, then writes the same doc '
        'shape as email signup and lands on the picked dashboard', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.nextGoogleEmail = email;

      await h.controller.signInWithGoogle();
      await h.settle();

      expect(h.state.status, AuthStatus.needsRole);
      expect(h.users.docs, isEmpty, reason: 'no doc until a role is picked');
      expect(authRedirect(h.state, '/login'), '/choose-role');
      expect(authRedirect(h.state, '/member/tasks'), '/choose-role');

      await h.controller.completeGoogleSignup(UserRole.member);
      await h.settle();

      final uid = h.state.user!.uid;
      expect(h.users.docs[uid]!.keys.toSet(), {
        'name',
        'email',
        'emailLower',
        'defaultRole',
        'skillTags',
        'createdAt',
      });
      expect(h.users.docs[uid]!['emailLower'], email);
      expect(h.users.docs[uid]!['name'], 'Google User');
      expect(h.users.docs[uid]!['email'], email);
      expect(h.users.docs[uid]!['defaultRole'], 'member');
      expect(h.state.status, AuthStatus.authenticated);
      expect(authRedirect(h.state, '/choose-role'), '/member/projects');
    });

    test('returning user skips the role picker', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.nextGoogleEmail = email;
      await h.controller.signInWithGoogle();
      await h.settle();
      await h.controller.completeGoogleSignup(UserRole.leader);
      await h.controller.signOut();
      await h.settle();
      h.history.clear();

      await h.controller.signInWithGoogle();
      await h.settle();

      expect(h.state.status, AuthStatus.authenticated);
      expect(h.state.sessionRole, UserRole.leader);
      expect(
        h.history.map((s) => s.status),
        isNot(contains(AuthStatus.needsRole)),
      );
    });

    test('cancelling at the role picker deletes the Auth account', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.nextGoogleEmail = email;
      await h.controller.signInWithGoogle();
      await h.settle();

      await h.controller.cancelGoogleSignup();
      await h.settle();

      expect(h.auth.calls, contains('deleteUser'));
      expect(h.auth.currentUser, isNull);
      expect(h.users.docs, isEmpty);
      expect(h.state.status, AuthStatus.unauthenticated);
    });

    test('dismissing the Google picker changes nothing', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);

      await h.controller.signInWithGoogle();
      await h.settle();

      expect(h.state.status, AuthStatus.unauthenticated);
      expect(h.history, isEmpty);
    });

    test('restart mid-picker asks for the role again instead of signing '
        'out', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.nextGoogleEmail = email;
      await h.controller.signInWithGoogle();
      await h.settle();

      // App killed on the role picker, then relaunched.
      final restarted = _Harness();
      addTearDown(restarted.dispose);
      restarted.auth.googleAccounts.addAll(h.auth.googleAccounts);
      restarted.auth.googleUids.addAll(h.auth.googleUids);
      restarted.auth.restoreGoogleSession(email);
      await restarted.settle();

      expect(restarted.state.status, AuthStatus.needsRole);
      expect(restarted.auth.calls, isNot(contains('signOut')));
    });

    test('a failed doc write keeps the user on the picker to retry', () async {
      final h = await _signedOutHarness();
      addTearDown(h.dispose);
      h.auth.nextGoogleEmail = email;
      await h.controller.signInWithGoogle();
      await h.settle();
      h.users.failCreate = true;

      await expectLater(
        h.controller.completeGoogleSignup(UserRole.leader),
        throwsA(isA<AuthFlowException>()),
      );
      expect(h.state.status, AuthStatus.needsRole);

      h.users.failCreate = false;
      await h.controller.completeGoogleSignup(UserRole.leader);
      expect(h.state.status, AuthStatus.authenticated);
    });
  });

  group('authRedirect', () {
    test('needsRole is held on /choose-role', () {
      final s = AuthState.needsRole(user: FakeUser('g'));
      expect(authRedirect(s, '/choose-role'), isNull);
      expect(authRedirect(s, '/login'), '/choose-role');
      expect(authRedirect(s, '/splash'), '/choose-role');
      expect(authRedirect(s, '/leader/projects'), '/choose-role');
      expect(
        authRedirect(const AuthState.unauthenticated(), '/choose-role'),
        '/login',
      );
    });

    final leader = AuthState.authenticated(
      user: FakeUser('a'),
      profile: AppUser(
        uid: 'a',
        name: 'A',
        email: 'a@example.com',
        defaultRole: UserRole.leader,
        skillTags: const [],
        createdAt: DateTime(2026),
      ),
    );

    test('loading and profileMissing hold on the splash', () {
      for (final s in [
        const AuthState.loading(),
        AuthState.loading(user: FakeUser('a')),
        AuthState.profileMissing(user: FakeUser('a')),
      ]) {
        expect(authRedirect(s, '/login'), '/splash');
        expect(authRedirect(s, '/leader/projects'), '/splash');
        expect(authRedirect(s, '/member/tasks'), '/splash');
        expect(authRedirect(s, '/splash'), isNull);
      }
    });

    test('unauthenticated only allows login/register', () {
      const s = AuthState.unauthenticated();
      expect(authRedirect(s, '/login'), isNull);
      expect(authRedirect(s, '/register'), isNull);
      expect(authRedirect(s, '/splash'), '/login');
      expect(authRedirect(s, '/leader/projects'), '/login');
    });

    test('authenticated is kept to its own role\'s routes', () {
      expect(authRedirect(leader, '/splash'), '/leader/projects');
      expect(authRedirect(leader, '/member/tasks'), '/leader/projects');
      expect(authRedirect(leader, '/leader/team'), isNull);
      expect(authRedirect(leader, '/forgot-password'), '/leader/projects');
    });
  });
}
