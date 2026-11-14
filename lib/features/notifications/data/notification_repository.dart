import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import 'app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

/// How many notifications the center shows (newest first).
const notificationPageSize = 50;

/// The recipient's side of `notifications` (Phase 8): list, unread count
/// and the read flag. Senders write through the repository of the flow
/// that causes the notice (help, comments, leave), in the same batch.
class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('notifications');

  /// Newest [notificationPageSize] for [uid]. Needs the composite index
  /// `notifications (userId ASC, createdAt DESC)` (firestore.indexes.json).
  Stream<List<AppNotification>> watchMine(String uid) => _col
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(notificationPageSize)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs)
            ?AppNotification.tryParse(doc.id, doc.data()),
        ],
      );

  /// Unread count for the bell. Equality filters only, so no composite
  /// index.
  Stream<int> watchUnreadCount(String uid) => _col
      .where('userId', isEqualTo: uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.size);

  /// Recipient only; the rules allow changing `read` and nothing else.
  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  /// Every unread notification of [uid], in batches of up to 450.
  Future<void> markAllRead(String uid) async {
    final unread = await _col
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final docs = unread.docs;
    for (var i = 0; i < docs.length; i += 450) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(450)) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    }
  }
}
