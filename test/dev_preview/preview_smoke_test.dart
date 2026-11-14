import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:team_project_manager/dev_preview/preview_app.dart';
import 'package:team_project_manager/dev_preview/preview_catalog.dart';
import 'package:team_project_manager/dev_preview/preview_overrides.dart';
import 'package:team_project_manager/dev_preview/preview_router.dart';
import 'package:team_project_manager/dev_preview/preview_session.dart';
import 'package:team_project_manager/features/auth/application/auth_controller.dart';

/// Lets streams, futures and (finite) animations run without
/// pumpAndSettle, which never settles on screens with a spinner.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _pumpPreview(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: previewOverrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const PreviewApp()),
  );
  await _settle(tester);
  return container;
}

/// Preview entries whose screen has a bug in existing app code (off-limits
/// under the add-only rule), with the reason they're skipped. Each is
/// listed in docs/PLAN.md under "Issues in existing code to report";
/// remove the entry once the screen is fixed.
const _knownIssues = <String, String>{
  'Project detail: Admin as Member':
      'existing ProjectDetailScreen overflows by 79 px at 390 px width; '
      'see docs/PLAN.md › Issues in existing code to report',
};

void main() {
  testWidgets('start page lists every screen, signed in as Admin', (
    tester,
  ) async {
    final container = await _pumpPreview(tester);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(find.textContaining('Signed in as Tariq Khan'), findsOneWidget);
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Member'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final entry in previewEntries) {
    final knownIssue = _knownIssues[entry.title];
    final name = 'opens ${entry.section.label} › ${entry.title}';
    testWidgets(
      knownIssue == null ? name : '$name (skipped: $knownIssue)',
      skip: knownIssue != null,
      (tester) async {
        final container = await _pumpPreview(tester);
        final role = entry.section.role;
        if (role != null) {
          // Not in runAsync: the auth listener starts resolving the profile
          // in the test's fake-async zone, and login() awaits that same
          // future, which only completes as fake time is pumped.
          var switched = false;
          unawaited(
            switchPreviewRole(
              current: container.read(authControllerProvider),
              controller: container.read(authControllerProvider.notifier),
              role: role,
            ).whenComplete(() => switched = true),
          );
          for (var i = 0; i < 50 && !switched; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(switched, isTrue, reason: 'role switch did not finish');
          await _settle(tester);
        }
        final router = container.read(previewRouterProvider);
        if (entry.tab) {
          router.go(entry.path);
        } else {
          router.push(entry.path);
        }
        await _settle(tester);

        expect(tester.takeException(), isNull);
        // `push` doesn't change currentConfiguration.uri (go_router keeps the
        // URL at the base location for imperative pushes), so read the
        // top-most route's state instead.
        expect(router.state.uri.path, entry.path);
        expect(find.text('ProTrack screen preview'), findsNothing);
        expect(find.byKey(const ValueKey('preview-back-to-list')), findsOne);
      },
    );
  }
}
