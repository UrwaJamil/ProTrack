import '../../features/notifications/data/app_notification.dart';
import '../../features/notifications/data/notification_repository.dart';
import 'live_store.dart';

/// In-memory [NotificationRepository] for the dev preview and widget
/// tests. Other preview fakes pass the notices they write to [write], so
/// they show up in the center like the real batches' writes.
class PreviewNotificationRepository implements NotificationRepository {
  PreviewNotificationRepository([
    Map<String, Map<String, dynamic>> seed = const {},
  ]) {
    seed.forEach((id, data) => _docs[id] = {...data});
  }

  final _docs = <String, Map<String, dynamic>>{};
  final _store = LiveStore();

  /// Raw documents by id, for test assertions.
  Map<String, Map<String, dynamic>> get docs => Map.unmodifiable(_docs);

  /// Stores a notice (stamped with `createdAt` if missing), like the
  /// sender's batch write.
  void write(String id, Map<String, dynamic> data) {
    _docs[id] = {'createdAt': DateTime.now(), ...data};
    _store.notify();
  }

  List<AppNotification> _mine(String uid) => [
    for (final e in _docs.entries)
      if (e.value['userId'] == uid) ?AppNotification.tryParse(e.key, e.value),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<AppNotification>> watchMine(String uid) =>
      _store.watch(() => _mine(uid).take(notificationPageSize).toList());

  @override
  Stream<int> watchUnreadCount(String uid) =>
      _store.watch(() => _mine(uid).where((n) => !n.read).length);

  @override
  Future<void> markRead(String id) async {
    final doc = _docs[id];
    if (doc == null) throw StateError('No such notification');
    doc['read'] = true;
    _store.notify();
  }

  @override
  Future<void> markAllRead(String uid) async {
    for (final doc in _docs.values) {
      if (doc['userId'] == uid) doc['read'] = true;
    }
    _store.notify();
  }
}
