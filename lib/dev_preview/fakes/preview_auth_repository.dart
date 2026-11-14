import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/auth_repository.dart';

/// A signed-in Firebase user without Firebase. Only the getters the app
/// reads are implemented; anything else throws [NoSuchMethodError].
class PreviewUser implements User {
  PreviewUser(this.uid, {this.email, this.displayName});

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewCredential implements UserCredential {
  _PreviewCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory [AuthRepository] for the dev preview. Any password is
/// accepted for a known email; nothing leaves the browser.
class PreviewAuthRepository implements AuthRepository {
  PreviewAuthRepository({
    required Map<String, String> uidByEmail,
    String? signedInUid,
  }) : _uidByEmail = {...uidByEmail} {
    if (signedInUid != null) currentUser = _userFor(signedInUid);
  }

  final Map<String, String> _uidByEmail;
  final _changes = StreamController<User?>.broadcast();
  var _nextUid = 0;

  @override
  User? currentUser;

  User _userFor(String uid) {
    final email = _uidByEmail.entries
        .firstWhere((e) => e.value == uid, orElse: () => MapEntry('', uid))
        .key;
    return PreviewUser(uid, email: email.isEmpty ? null : email);
  }

  void _setUser(User? user) {
    currentUser = user;
    _changes.add(user);
  }

  /// Like Firebase: emits the current user on subscription, then changes.
  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final uid = _uidByEmail[email.trim().toLowerCase()];
    if (uid == null) throw FirebaseAuthException(code: 'invalid-credential');
    _setUser(_userFor(uid));
    return _PreviewCredential(currentUser);
  }

  @override
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (_uidByEmail.containsKey(key)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final uid = 'preview-new-${_nextUid++}';
    _uidByEmail[key] = uid;
    _setUser(_userFor(uid));
    return _PreviewCredential(currentUser);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  /// Shown so the screens look like they do on web; tapping it behaves
  /// like dismissing the picker.
  @override
  bool get supportsGoogleSignIn => true;

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  bool isGoogleUser(User user) => false;

  @override
  Future<void> signOut() async => _setUser(null);

  @override
  Future<void> deleteUser(User user) async {
    _uidByEmail.removeWhere((_, uid) => uid == user.uid);
    _setUser(null);
  }
}
