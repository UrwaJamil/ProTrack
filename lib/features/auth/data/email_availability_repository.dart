import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_repository.dart';

final emailAvailabilityRepositoryProvider =
    Provider<EmailAvailabilityRepository>(
      (ref) => EmailAvailabilityRepository(ref.watch(firestoreProvider)),
    );

/// The `emailIndex` doc id for [email]: trimmed and lower-cased, matching
/// how Firebase Auth compares emails (and the `.lower()` check in
/// `firestore.rules`).
String emailIndexKey(String email) => email.trim().toLowerCase();

/// Whether [email] can be used as an `emailIndex` doc id at all. Firestore
/// ids can't contain `/`; such (rare, but RFC-legal) addresses simply skip
/// the availability check.
bool isIndexableEmail(String email) => !emailIndexKey(email).contains('/');

/// Answers "is this email already registered?" before the user has an
/// account, via `emailIndex/{email}` docs written alongside `users/{uid}`.
/// Firebase's email enumeration protection stays on, so this index is the
/// only pre-auth lookup. It's advisory: accounts created before the index
/// existed aren't in it, and the real registration attempt is still the
/// source of truth.
class EmailAvailabilityRepository {
  EmailAvailabilityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<bool> isTaken(String email) async {
    final doc = await _firestore
        .collection('emailIndex')
        .doc(emailIndexKey(email))
        .get();
    return doc.exists;
  }
}
