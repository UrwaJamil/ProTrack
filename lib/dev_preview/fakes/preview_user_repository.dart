import '../../features/auth/data/app_user.dart';
import '../../features/auth/data/email_availability_repository.dart';
import '../../features/auth/data/user_repository.dart';

/// In-memory `users` collection for the dev preview. Profiles are stored
/// as the maps [AppUser.toMap] writes and read back with [AppUser.fromMap],
/// so the real serialization runs.
class PreviewUserRepository implements UserRepository {
  PreviewUserRepository(Iterable<AppUser> initial) {
    for (final user in initial) {
      _docs[user.uid] = user.toMap();
    }
  }

  final _docs = <String, Map<String, dynamic>>{};

  Iterable<String> get emails =>
      _docs.values.map((d) => (d['emailLower'] as String?) ?? '');

  AppUser _read(String uid) => AppUser.fromMap(uid, _docs[uid]!);

  @override
  Future<AppUser?> fetch(String uid) async =>
      _docs.containsKey(uid) ? _read(uid) : null;

  @override
  Future<void> create(AppUser user) async => _docs[user.uid] = user.toMap();

  @override
  Future<void> update(String uid, Map<String, dynamic> patch) async =>
      _docs[uid]!.addAll(patch);

  @override
  Future<List<AppUser>> searchByEmailPrefix(
    String prefix, {
    int limit = 10,
  }) async {
    final q = emailLowerFor(prefix);
    if (q.isEmpty) return const [];
    final matches = [
      for (final uid in _docs.keys)
        if ((_docs[uid]!['emailLower'] as String).startsWith(q)) _read(uid),
    ]..sort((a, b) => a.email.compareTo(b.email));
    return matches.take(limit).toList();
  }

  @override
  Future<Map<String, AppUser>> fetchMany(Iterable<String> uids) async => {
    for (final uid in uids)
      if (_docs.containsKey(uid)) uid: _read(uid),
  };
}

/// The register screen's "Email already in use" check, answered from the
/// preview's users.
class PreviewEmailAvailabilityRepository
    implements EmailAvailabilityRepository {
  PreviewEmailAvailabilityRepository(this._users);

  final PreviewUserRepository _users;

  @override
  Future<bool> isTaken(String email) async =>
      _users.emails.contains(emailIndexKey(email));
}
