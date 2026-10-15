import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/application/auth_controller.dart';
import 'package:team_project_manager/features/auth/presentation/forgot_password_screen.dart';
import 'package:team_project_manager/features/auth/presentation/login_screen.dart';
import 'package:team_project_manager/routing/app_router.dart';

import 'support/fake_auth.dart';
import 'support/finders.dart';

/// Login + reset screens behind a minimal router (no auth redirects), with
/// the same `extra` hand-off the real router uses.
Widget _app(FakeAuthRepository auth) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) =>
            ForgotPasswordScreen(initialEmail: state.extra as String?),
      ),
    ],
  );
  return ProviderScope(
    overrides: fakeAuthOverrides(auth: auth),
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _openReset(WidgetTester tester, {String typed = ''}) async {
  if (typed.isNotEmpty) {
    await tester.enterText(fieldWithHint('you@company.com'), typed);
  }
  await tester.tap(find.text('Forgot password?'));
  await tester.pumpAndSettle();
}

Finder get _sendButton => find.widgetWithText(FilledButton, 'Send reset link');

void main() {
  group('reset screen', () {
    testWidgets('pre-fills the email typed on login, and Back returns there', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(_app(auth));

      await _openReset(tester, typed: ' typed@example.com ');
      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.text('typed@example.com'), findsOneWidget);

      await tester.ensureVisible(find.text('Back to login'));
      await tester.tap(find.text('Back to login'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Log In'), findsOneWidget);
      expect(find.text(' typed@example.com '), findsOneWidget);
    });

    testWidgets('empty login email opens with an empty field', (tester) async {
      await tester.pumpWidget(_app(FakeAuthRepository()));
      await _openReset(tester);
      final field = tester.widget<TextField>(fieldWithHint('you@company.com'));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('send shows the neutral message', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(_app(auth));
      await _openReset(tester, typed: 'anyone@example.com');

      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(auth.resetRequests, ['anyone@example.com']);
      expect(find.text(passwordResetSentMessage), findsOneWidget);
      expect(_sendButton, findsNothing);

      await tester.tap(find.text('Send again'));
      await tester.pumpAndSettle();
      expect(_sendButton, findsOneWidget);
    });

    testWidgets('unregistered email (user-not-found) looks the same', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..resetErrorCode = 'user-not-found';
      await tester.pumpWidget(_app(auth));
      await _openReset(tester, typed: 'nobody@example.com');

      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(find.text(passwordResetSentMessage), findsOneWidget);
    });

    testWidgets('malformed email is rejected without a request', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(_app(auth));
      await _openReset(tester, typed: 'not-an-email');

      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(auth.resetRequests, isEmpty);
    });

    testWidgets('real failures show an error and keep the form', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..resetErrorCode = 'network-request-failed';
      await tester.pumpWidget(_app(auth));
      await _openReset(tester, typed: 'a@example.com');

      await tester.tap(_sendButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text(passwordResetSentMessage), findsNothing);
      expect(_sendButton, findsOneWidget);
    });
  });

  group('AuthController.sendPasswordReset', () {
    late FakeAuthRepository auth;
    late ProviderContainer container;

    setUp(() {
      auth = FakeAuthRepository();
      container = ProviderContainer(overrides: fakeAuthOverrides(auth: auth));
    });
    tearDown(() => container.dispose());

    AuthController controller() =>
        container.read(authControllerProvider.notifier);

    test('treats user-not-found as success', () async {
      auth.resetErrorCode = 'user-not-found';
      await controller().sendPasswordReset('x@example.com');
      expect(auth.resetRequests, ['x@example.com']);
    });

    for (final code in [
      'invalid-email',
      'network-request-failed',
      'too-many-requests',
    ]) {
      test('rethrows $code', () async {
        auth.resetErrorCode = code;
        await expectLater(
          controller().sendPasswordReset('x@example.com'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'code',
              contains(code),
            ),
          ),
        );
      });
    }
  });

  test('authRedirect: reset screen is open only while signed out', () {
    expect(
      authRedirect(const AuthState.unauthenticated(), '/forgot-password'),
      isNull,
    );
    expect(
      authRedirect(const AuthState.loading(), '/forgot-password'),
      '/splash',
    );
  });
}
