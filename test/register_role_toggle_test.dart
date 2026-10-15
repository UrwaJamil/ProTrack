import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/application/auth_controller.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/auth/data/auth_repository.dart';
import 'package:team_project_manager/features/auth/data/email_availability_repository.dart';
import 'package:team_project_manager/features/auth/presentation/register_screen.dart';

import 'support/fake_auth.dart';
import 'support/finders.dart';

/// Records exactly what [UserRole] the register screen hands to the
/// controller, without touching Firebase — proves whether the toggle's
/// tapped value actually reaches `register()`.
class _RecordingAuthController extends AuthController {
  UserRole? capturedRole;

  @override
  AuthState build() => const AuthState.unauthenticated();

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole defaultRole,
  }) async {
    capturedRole = defaultRole;
  }
}

void main() {
  testWidgets('tapping Member then Create account sends UserRole.member', (
    tester,
  ) async {
    final controller = _RecordingAuthController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => controller),
          emailAvailabilityRepositoryProvider.overrideWithValue(
            FakeEmailAvailabilityRepository(),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RegisterScreen(),
        ),
      ),
    );

    // Sanity check: default toggle state is Admin (leader).
    expect(controller.capturedRole, isNull);

    await tester.tap(find.text('Member'));
    await tester.pump();

    await tester.enterText(fieldWithHint('Jane Doe'), 'Test User');
    await tester.enterText(
      fieldWithHint('you@company.com'),
      'test.member@example.com',
    );
    await tester.enterText(
      fieldWithHint('Create a strong password'),
      'Passw0rd!',
    );

    await tester.pump();
    final submit = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(controller.capturedRole, UserRole.member);
  });

  testWidgets(
    'tapping Admin (default) then Create account sends UserRole.leader',
    (tester) async {
      final controller = _RecordingAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => controller),
            emailAvailabilityRepositoryProvider.overrideWithValue(
              FakeEmailAvailabilityRepository(),
            ),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RegisterScreen(),
          ),
        ),
      );

      await tester.enterText(fieldWithHint('Jane Doe'), 'Test User');
      await tester.enterText(
        fieldWithHint('you@company.com'),
        'test.leader@example.com',
      );
      await tester.enterText(
        fieldWithHint('Create a strong password'),
        'Passw0rd!',
      );

      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(controller.capturedRole, UserRole.leader);
    },
  );

  testWidgets(
    'Create account stays disabled until the password meets every rule',
    (tester) async {
      final controller = _RecordingAuthController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => controller),
            emailAvailabilityRepositoryProvider.overrideWithValue(
              FakeEmailAvailabilityRepository(),
            ),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RegisterScreen(),
          ),
        ),
      );
      final password = fieldWithHint('Create a strong password');
      FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create Account'),
      );

      expect(button().onPressed, isNull);
      await tester.enterText(password, 'password123');
      await tester.pump();
      expect(button().onPressed, isNull);
      expect(find.text('Weak'), findsOneWidget);

      await tester.enterText(password, 'Passw0rd!');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      expect(find.text('Good'), findsOneWidget);
    },
  );
}
