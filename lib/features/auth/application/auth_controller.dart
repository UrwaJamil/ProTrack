import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';

const accountSetupIncompleteMessage =
    'Account setup was not completed. Please register again.';
const registrationFailedMessage =
    "We couldn't finish creating your account. Please try again.";
const profileLoadFailedMessage =
    "We couldn't load your account. Please try logging in again.";

void authLog(String message) {
  if (kDebugMode) debugPrint('[auth] $message');
}

enum AuthStatus {
  /// Initial auth check, or signed in with the profile not yet resolved.
  loading,

  /// Signed in, `users/{uid}` loaded, role known.
  authenticated,

  /// Not signed in.
  unauthenticated,

  /// Signed in but no `users/{uid}` document exists. Transient: the
  /// controller signs the user out straight away.
  profileMissing,

  /// Signed in with Google for the first time (no `users/{uid}` doc yet).
  /// Google doesn't collect a `defaultRole`, so the router holds on
  /// `/choose-role` until [AuthController.completeGoogleSignup] writes the
  /// doc, or [AuthController.cancelGoogleSignup] discards the account.
  needsRole,
}

/// A user-facing failure from an auth flow, shown as-is by the screens.
class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthState {
  const AuthState._({
    required this.status,
    this.user,
    this.profile,
    this.message,
  });

  const AuthState.loading({User? user})
    : this._(status: AuthStatus.loading, user: user);

  const AuthState.authenticated({required User user, required AppUser profile})
    : this._(status: AuthStatus.authenticated, user: user, profile: profile);

  /// [message] explains why the user was signed out, if it wasn't their
  /// own choice (e.g. [accountSetupIncompleteMessage]).
  const AuthState.unauthenticated({String? message})
    : this._(status: AuthStatus.unauthenticated, message: message);

  const AuthState.profileMissing({required User user})
    : this._(status: AuthStatus.profileMissing, user: user);

  const AuthState.needsRole({required User user})
    : this._(status: AuthStatus.needsRole, user: user);

  final AuthStatus status;
  final User? user;
  final AppUser? profile;
  final String? message;

  /// Which dashboard this session lands on: the account's stored
  /// `users/{uid}.defaultRole` (FR-1.3). Only known once authenticated —
  /// there is deliberately no fallback role.
  UserRole? get sessionRole =>
      status == AuthStatus.authenticated ? profile!.defaultRole : null;

  AuthState withProfile(AppUser profile) => AuthState._(
    status: status,
    user: user,
    profile: profile,
    message: message,
  );
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSub;

  /// True while [register] runs. Firebase signs the new user in (and fires
  /// `authStateChanges`) before their `users/{uid}` doc exists, so the
  /// listener must not try to resolve the session then — [register] alone
  /// sets it, once the doc is written.
  bool _isRegistering = false;

  /// The in-flight profile resolution, so concurrent callers (the auth
  /// listener and [login]) share one fetch instead of racing.
  Future<void>? _settling;
  String? _settlingUid;

  /// Why the next sign-out happens, carried into the resulting
  /// unauthenticated state (the `authStateChanges(null)` event arrives
  /// separately and must not wipe it).
  String? _signOutMessage;

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);

  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    _authSub = repo.authStateChanges().listen(_onAuthChanged);
    ref.onDispose(() => _authSub?.cancel());
    return const AuthState.loading();
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      authLog('authStateChanges: signed out');
      if (state.status != AuthStatus.unauthenticated) {
        state = AuthState.unauthenticated(message: _signOutMessage);
      }
      return;
    }
    if (_isRegistering) {
      authLog(
        'authStateChanges: uid=${user.uid} ignored (registration in progress)',
      );
      return;
    }
    if ((state.status == AuthStatus.authenticated ||
            state.status == AuthStatus.needsRole) &&
        state.user?.uid == user.uid) {
      return;
    }
    authLog('authStateChanges: uid=${user.uid} -> resolving profile');
    await _settleSessionFor(user);
  }

  Future<void> _settleSessionFor(User user) {
    final inFlight = _settling;
    if (inFlight != null && _settlingUid == user.uid) return inFlight;
    _settlingUid = user.uid;
    late final Future<void> future;
    future = _resolveProfile(user).whenComplete(() {
      if (identical(_settling, future)) {
        _settling = null;
        _settlingUid = null;
      }
    });
    return _settling = future;
  }

  /// Resolves the session from the account's stored `users/{uid}` doc —
  /// the single source of truth for the role. No doc (or an unreadable
  /// one) never falls back to a role: the user is signed out instead.
  Future<void> _resolveProfile(User user) async {
    state = AuthState.loading(user: user);
    final AppUser? profile;
    try {
      profile = await _userRepo.fetch(user.uid);
    } catch (e) {
      authLog('profile fetch for uid=${user.uid} failed: $e -> signing out');
      await _signOutWith(profileLoadFailedMessage);
      return;
    }
    if (profile == null && _authRepo.isGoogleUser(user)) {
      // First Google sign-in, or one abandoned at the role picker (app
      // killed): ask for the role rather than calling setup incomplete.
      authLog('no users/${user.uid} doc for Google user -> needsRole');
      state = AuthState.needsRole(user: user);
      return;
    }
    if (profile == null) {
      authLog('no users/${user.uid} doc -> profileMissing, signing out');
      state = AuthState.profileMissing(user: user);
      await _signOutWith(accountSetupIncompleteMessage);
      return;
    }
    authLog(
      'profile loaded uid=${user.uid} defaultRole="${profile.defaultRole.value}"',
    );
    state = AuthState.authenticated(user: user, profile: profile);
  }

  Future<void> _signOutWith(String message) async {
    _signOutMessage = message;
    try {
      await _authRepo.signOut();
    } finally {
      state = AuthState.unauthenticated(message: message);
    }
  }

  /// Takes no role: the dashboard always comes from the account's stored
  /// `defaultRole` (FR-1.3). A missing profile surfaces through
  /// [AuthState.message] on the login screen, not as a thrown error,
  /// because the screen has been replaced by the splash by then.
  Future<void> login({required String email, required String password}) async {
    _signOutMessage = null;
    if (state.message != null) state = const AuthState.unauthenticated();
    final credential = await _authRepo.signIn(email: email, password: password);
    await _settleSessionFor(credential.user!);
  }

  /// Creates the Auth account and the `users/{uid}` doc, then sets the
  /// session from the role that was written. If the doc write fails, the
  /// Auth account is rolled back so none exists without a profile, and an
  /// [AuthFlowException] is thrown for the register screen to show.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole defaultRole,
  }) async {
    _signOutMessage = null;
    _isRegistering = true;
    try {
      final credential = await _authRepo.register(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final profile = AppUser(
        uid: user.uid,
        name: name,
        email: email,
        defaultRole: defaultRole,
        skillTags: const [],
        createdAt: DateTime.now(),
      );
      authLog(
        'register(): selected role=$defaultRole -> writing '
        'users/${user.uid}.defaultRole="${profile.toMap()['defaultRole']}"',
      );
      try {
        await _userRepo.create(profile);
      } catch (e) {
        authLog(
          'register(): users.create failed: $e -> rolling back Auth user',
        );
        await _rollBackAuthUser(user);
        throw const AuthFlowException(registrationFailedMessage);
      }
      authLog('register(): users/${user.uid} written -> authenticated');
      state = AuthState.authenticated(user: user, profile: profile);
    } finally {
      _isRegistering = false;
    }
  }

  /// Requests a password-reset email. Completes normally whether or not an
  /// account exists for [email] — `user-not-found` (only reported when
  /// enumeration protection is off) is swallowed so the screen can't reveal
  /// which emails are registered. Real failures (`invalid-email`, network,
  /// rate limiting) are rethrown. Never logs the email.
  Future<void> sendPasswordReset(String email) async {
    authLog('password reset requested');
    try {
      await _authRepo.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      authLog('password reset failed: ${e.code}');
      rethrow;
    }
  }

  /// Signs in with Google. A returning user (doc exists) lands on their
  /// stored `defaultRole`'s dashboard like a password login; a first-time
  /// user ends in [AuthStatus.needsRole]. Dismissing the picker is a no-op.
  Future<void> signInWithGoogle() async {
    _signOutMessage = null;
    if (state.message != null) state = const AuthState.unauthenticated();
    final credential = await _authRepo.signInWithGoogle();
    if (credential == null) {
      authLog('signInWithGoogle(): cancelled by user');
      return;
    }
    await _settleSessionFor(credential.user!);
  }

  /// Finishes a first Google sign-in: writes the same `users/{uid}` shape
  /// as email signup (name/email from the Google profile) with the picked
  /// [defaultRole], then lands on that dashboard. The doc is only written
  /// here, once the role is known, so it never exists without one.
  Future<void> completeGoogleSignup(UserRole defaultRole) async {
    final user = state.user;
    if (state.status != AuthStatus.needsRole || user == null) {
      throw StateError('completeGoogleSignup() outside the needsRole state');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthFlowException(registrationFailedMessage);
    }
    final displayName = user.displayName?.trim() ?? '';
    final profile = AppUser(
      uid: user.uid,
      name: displayName.isNotEmpty ? displayName : email.split('@').first,
      email: email,
      defaultRole: defaultRole,
      skillTags: const [],
      createdAt: DateTime.now(),
    );
    authLog(
      'completeGoogleSignup(): writing '
      'users/${user.uid}.defaultRole="${defaultRole.value}"',
    );
    try {
      await _userRepo.create(profile);
    } catch (e) {
      // Stay on the role picker so the user can retry or cancel.
      authLog('completeGoogleSignup(): users.create failed: $e');
      throw const AuthFlowException(registrationFailedMessage);
    }
    state = AuthState.authenticated(user: user, profile: profile);
  }

  /// Abandons a first Google sign-in from the role picker: deletes the new
  /// Auth account so none exists without a profile doc.
  Future<void> cancelGoogleSignup() async {
    final user = state.user;
    if (state.status != AuthStatus.needsRole || user == null) return;
    authLog('cancelGoogleSignup(): discarding Auth user ${user.uid}');
    await _rollBackAuthUser(user);
  }

  Future<void> _rollBackAuthUser(User user) async {
    _signOutMessage = null;
    try {
      await _authRepo.deleteUser(user);
      authLog('rollback: Auth user ${user.uid} deleted');
    } catch (e) {
      authLog('rollback: deleting Auth user failed: $e -> signing out');
      try {
        await _authRepo.signOut();
      } catch (e) {
        authLog('rollback: sign-out after failed delete also failed: $e');
      }
    }
    state = const AuthState.unauthenticated();
  }

  Future<void> signOut() async {
    _signOutMessage = null;
    await _authRepo.signOut();
    state = const AuthState.unauthenticated();
  }

  Future<void> updateProfile({String? name, List<String>? skillTags}) async {
    final current = state.profile;
    if (current == null) return;
    final updated = current.copyWith(name: name, skillTags: skillTags);
    final patch = <String, dynamic>{
      if (name != null) 'name': updated.name,
      if (skillTags != null) 'skillTags': updated.skillTags,
    };
    await _userRepo.update(current.uid, patch);
    state = state.withProfile(updated);
  }
}
