import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

const _googleProviderId = 'google.com';

/// Thin wrapper around [FirebaseAuth] so the rest of the app never talks to
/// the Firebase SDK directly (CLAUDE.md: UI/controllers only go through a
/// repository).
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// google_sign_in must be initialized exactly once before use (Android).
  Future<void>? _googleInit;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends Firebase's hosted password-reset email. With email enumeration
  /// protection on, this succeeds silently for unregistered addresses.
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Web uses Firebase's own popup; Android uses google_sign_in's native
  /// account picker. Windows/desktop isn't supported by google_sign_in, and
  /// iOS isn't configured for this project, so the button is hidden there.
  bool get supportsGoogleSignIn =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// Signs in with Google. Returns `null` if the user dismissed the account
  /// picker / popup; throws [FirebaseAuthException] or
  /// [GoogleSignInException] for real failures.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        return await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return null;
        }
        rethrow;
      }
    }

    // The web client id (serverClientId) comes from google-services.json.
    await (_googleInit ??= GoogleSignIn.instance.initialize());
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Whether [user] signed in through Google (vs email/password only).
  bool isGoogleUser(User user) =>
      user.providerData.any((info) => info.providerId == _googleProviderId);

  Future<void> signOut() async {
    await _signOutOfGoogle();
    await _auth.signOut();
  }

  /// Permanently deletes [user]'s Auth account (used to roll back a
  /// registration whose `users/{uid}` profile write failed, or a Google
  /// sign-up abandoned at the role picker).
  Future<void> deleteUser(User user) async {
    await user.delete();
    await _signOutOfGoogle();
  }

  /// Clears google_sign_in's cached account so the next sign-in shows the
  /// account picker again instead of silently reusing the last account.
  Future<void> _signOutOfGoogle() async {
    final init = _googleInit;
    if (init == null) return;
    try {
      await init;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Best effort: Firebase sign-out is what actually ends the session.
    }
  }
}
