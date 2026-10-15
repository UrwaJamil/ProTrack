import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/auth/presentation/login_screen.dart';
import 'package:team_project_manager/features/auth/presentation/register_screen.dart';

import 'support/fake_auth.dart';

// These tests render the login/register screens in isolation (not the
// full app/router), with in-memory fakes in place of the Firebase-backed
// repositories.
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: fakeAuthOverrides(),
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  testWidgets('login screen shows logo, fields and link, but no role toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    expect(find.text('ProTrack'), findsOneWidget);
    // The landing dashboard comes from users/{uid}.defaultRole, never a
    // login-screen choice.
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Member'), findsNothing);
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log In'), findsOneWidget);
    expect(
      find.text(
        "Don't have an account? Create new account",
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('register screen shows logo, role toggle, fields and link', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));

    expect(find.text('ProTrack'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
    expect(
      find.text('Already have an account? Log in', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('login validation blocks submit with empty fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('narrow layout still shows the login form in a card', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const LoginScreen()));

    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('wide layout centers the login form in a card', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const LoginScreen()));

    expect(find.byType(Card), findsOneWidget);
  });
}
