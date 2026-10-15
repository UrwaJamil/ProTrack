import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/email_availability_repository.dart';

const emailCheckDebounce = Duration(milliseconds: 500);

final _plausibleEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

enum EmailAvailabilityStatus {
  /// Nothing to show: field empty, not yet a plausible email, or edited
  /// since the last check and the debounce hasn't fired.
  idle,
  checking,
  taken,
  available,

  /// The lookup failed (offline, etc.). Registration still proceeds and
  /// remains the source of truth.
  error,
}

class EmailAvailability {
  const EmailAvailability(this.status, [this.email]);

  const EmailAvailability.idle() : this(EmailAvailabilityStatus.idle);

  final EmailAvailabilityStatus status;

  /// The (normalized) email this status describes.
  final String? email;
}

/// Drives the register screen's inline "Checking… / Email already in use /
/// Available" hint (CLAUDE.md §9). Purely advisory — it never blocks the
/// Create account button.
final emailAvailabilityControllerProvider =
    NotifierProvider.autoDispose<
      EmailAvailabilityController,
      EmailAvailability
    >(EmailAvailabilityController.new);

class EmailAvailabilityController extends Notifier<EmailAvailability> {
  Timer? _debounce;

  @override
  EmailAvailability build() {
    ref.onDispose(() => _debounce?.cancel());
    return const EmailAvailability.idle();
  }

  /// Call on every keystroke: checks [emailCheckDebounce] after typing stops.
  void onChanged(String email) {
    _debounce?.cancel();
    final key = _checkableKey(email);
    if (key == null) {
      state = const EmailAvailability.idle();
      return;
    }
    if (key == state.email && state.status != EmailAvailabilityStatus.idle) {
      return; // e.g. trailing whitespace added — same address, same answer.
    }
    state = const EmailAvailability.idle();
    _debounce = Timer(emailCheckDebounce, () => _check(key));
  }

  /// Call when the field loses focus: checks straight away unless this
  /// exact address is already checked or being checked.
  void checkNow(String email) {
    final key = _checkableKey(email);
    if (key == null) return;
    if (key == state.email && state.status != EmailAvailabilityStatus.idle) {
      return;
    }
    _debounce?.cancel();
    _check(key);
  }

  String? _checkableKey(String email) {
    final key = emailIndexKey(email);
    if (!_plausibleEmail.hasMatch(key) || !isIndexableEmail(key)) return null;
    return key;
  }

  Future<void> _check(String key) async {
    state = EmailAvailability(EmailAvailabilityStatus.checking, key);
    EmailAvailabilityStatus result;
    try {
      final taken = await ref
          .read(emailAvailabilityRepositoryProvider)
          .isTaken(key);
      result = taken
          ? EmailAvailabilityStatus.taken
          : EmailAvailabilityStatus.available;
    } catch (_) {
      result = EmailAvailabilityStatus.error;
    }
    // Drop answers for an address the user has since edited away from.
    if (!ref.mounted ||
        state.email != key ||
        state.status != EmailAvailabilityStatus.checking) {
      return;
    }
    state = EmailAvailability(result, key);
  }
}
