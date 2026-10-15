import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';
import 'email_availability_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

/// Thin wrapper around the `users/{uid}` Firestore collection.
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser?> fetch(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final user = AppUser.fromMap(uid, data);
    // Back-fill the search field on profiles created before it existed.
    // Best effort: a failure only means they aren't searchable yet.
    if (data['emailLower'] == null && user.email.isNotEmpty) {
      _users.doc(uid).update({
        'emailLower': emailLowerFor(user.email),
      }).ignore();
    }
    return user;
  }

  /// Users whose email starts with [prefix] (case-insensitive), for the
  /// "Assign Team Member" search. A range on the single field
  /// `emailLower`, so Firestore's automatic index serves it — no composite
  /// index. Firestore rules require list queries to set `limit <= 30`.
  Future<List<AppUser>> searchByEmailPrefix(
    String prefix, {
    int limit = 10,
  }) async {
    final q = emailLowerFor(prefix);
    if (q.isEmpty) return const [];
    final snap = await _users
        .orderBy('emailLower')
        .startAt([q])
        .endAt(['$q'])
        .limit(limit)
        .get();
    return [for (final doc in snap.docs) AppUser.fromMap(doc.id, doc.data())];
  }

  /// Profiles for [uids] (missing ones are simply absent), in batches of
  /// 30 — Firestore's `whereIn` cap and the rules' list-query limit.
  Future<Map<String, AppUser>> fetchMany(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    final result = <String, AppUser>{};
    for (var i = 0; i < ids.length; i += 30) {
      final end = i + 30 > ids.length ? ids.length : i + 30;
      final snap = await _users
          .where(FieldPath.documentId, whereIn: ids.sublist(i, end))
          .limit(30)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = AppUser.fromMap(doc.id, doc.data());
      }
    }
    return result;
  }

  /// Writes `users/{uid}` and its `emailIndex/{email}` entry atomically, so
  /// the register screen's availability check sees every new account.
  Future<void> create(AppUser user) {
    final batch = _firestore.batch()..set(_users.doc(user.uid), user.toMap());
    if (isIndexableEmail(user.email)) {
      batch.set(
        _firestore.collection('emailIndex').doc(emailIndexKey(user.email)),
        {'uid': user.uid},
      );
    }
    return batch.commit();
  }

  Future<void> update(String uid, Map<String, dynamic> patch) =>
      _users.doc(uid).update(patch);
}
