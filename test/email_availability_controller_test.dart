import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/application/email_availability_controller.dart';
import 'package:team_project_manager/features/auth/data/email_availability_repository.dart';

import 'support/fake_auth.dart';

// testWidgets runs in a fake-async zone, so `tester.pump(duration)` drives
// the debounce timer deterministically.
void main() {
  late FakeEmailAvailabilityRepository repo;
  late ProviderContainer container;

  EmailAvailabilityController controller() =>
      container.read(emailAvailabilityControllerProvider.notifier);
  EmailAvailabilityStatus status() =>
      container.read(emailAvailabilityControllerProvider).status;

  void setUpContainer() {
    repo = FakeEmailAvailabilityRepository()..taken.add('used@example.com');
    container = ProviderContainer(
      overrides: [emailAvailabilityRepositoryProvider.overrideWithValue(repo)],
    );
    // Keep the autoDispose provider alive for the whole test.
    container.listen(emailAvailabilityControllerProvider, (_, _) {});
  }

  testWidgets('waits for the debounce, then reports taken', (tester) async {
    setUpContainer();
    controller().onChanged('Used@Example.com ');
    await tester.pump(const Duration(milliseconds: 499));
    expect(repo.lookups, isEmpty);
    expect(status(), EmailAvailabilityStatus.idle);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repo.lookups, ['used@example.com']);
    expect(status(), EmailAvailabilityStatus.taken);
    container.dispose();
  });

  testWidgets('only the last keystroke in a burst is looked up', (
    tester,
  ) async {
    setUpContainer();
    for (final partial in ['new@ex.co', 'new@exa.co', 'new@example.com']) {
      controller().onChanged(partial);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(emailCheckDebounce);
    expect(repo.lookups, ['new@example.com']);
    expect(status(), EmailAvailabilityStatus.available);
    container.dispose();
  });

  testWidgets('blur checks immediately and skips a repeat check', (
    tester,
  ) async {
    setUpContainer();
    controller().onChanged('new@example.com');
    controller().checkNow('new@example.com');
    await tester.pump();
    expect(status(), EmailAvailabilityStatus.available);

    await tester.pump(emailCheckDebounce); // cancelled timer must not refire
    controller().checkNow('new@example.com');
    await tester.pump();
    expect(repo.lookups, ['new@example.com']);
    container.dispose();
  });

  testWidgets('a reply for an edited-away address is dropped', (tester) async {
    setUpContainer();
    final slow = repo.pending = Completer<bool>();
    controller().checkNow('used@example.com');
    expect(status(), EmailAvailabilityStatus.checking);

    controller().onChanged('used@example.co'); // user keeps typing
    slow.complete(true);
    await tester.pump();
    expect(status(), EmailAvailabilityStatus.idle);
    repo.pending = null;
    await tester.pump(emailCheckDebounce);
    container.dispose();
  });

  testWidgets('implausible input never hits Firestore', (tester) async {
    setUpContainer();
    controller().onChanged('not-an-email');
    controller().checkNow('a/b@example.com');
    await tester.pump(emailCheckDebounce);
    expect(repo.lookups, isEmpty);
    expect(status(), EmailAvailabilityStatus.idle);
    container.dispose();
  });

  testWidgets('lookup failure shows error, not taken', (tester) async {
    setUpContainer();
    repo.fail = true;
    controller().checkNow('new@example.com');
    await tester.pump();
    expect(status(), EmailAvailabilityStatus.error);
    container.dispose();
  });
}
