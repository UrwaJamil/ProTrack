import '../../features/leave/data/leave_repository.dart';
import '../../features/leave/data/leave_request.dart';
import '../../features/leave/data/leave_settings.dart';
import '../../features/leave/data/leave_type.dart';
import '../../features/leave/data/working_days.dart';
import '../../features/notifications/data/notification_payloads.dart';
import 'live_store.dart';
import 'preview_notification_repository.dart';

/// In-memory [LeaveRepository] for the dev preview and widget tests.
/// Mirrors the real batches: approving also writes the `leaveDays` entry,
/// and every decision records the requester's notification.
class PreviewLeaveRepository implements LeaveRepository {
  PreviewLeaveRepository({
    List<LeaveRequest> requests = const [],
    this.settings = LeaveSettings.defaults,
    this.sink,
  }) {
    for (final r in requests) {
      _requests[r.id] = r;
      if (r.status == LeaveStatus.approved) _days[r.id] = _daysOf(r);
    }
  }

  LeaveSettings settings;

  /// Where notices also go, so the preview's notification center shows
  /// them (Phase 8).
  final PreviewNotificationRepository? sink;

  void _notify(String id, Map<String, dynamic> data) {
    notifications[id] = data..['createdAt'] = DateTime.now();
    sink?.write(id, data);
  }
  final _requests = <String, LeaveRequest>{};
  final _days = <String, LeaveDays>{};
  final _store = LiveStore();
  var _nextId = 0;

  /// Notifications written by [decide], keyed by id.
  final notifications = <String, Map<String, dynamic>>{};

  /// Every request, for test assertions.
  Map<String, LeaveRequest> get requests => Map.unmodifiable(_requests);

  static LeaveDays _daysOf(LeaveRequest r) => LeaveDays(
    id: r.id,
    userId: r.userId,
    fromDate: r.fromDate,
    toDate: r.toDate,
  );

  @override
  Stream<List<LeaveRequest>> watchMine(String uid) => _store.watch(
    () => [
      for (final r in _requests.values)
        if (r.userId == uid) r,
    ],
  );

  @override
  Stream<List<LeaveRequest>> watchForApprover(String uid) => _store.watch(
    () => [
      for (final r in _requests.values)
        if (r.approverIds.contains(uid)) r,
    ],
  );

  @override
  Stream<LeaveRequest?> watchRequest(String id) =>
      _store.watch(() => _requests[id]);

  @override
  Stream<LeaveSettings> watchSettings() => _store.watch(() => settings);

  @override
  Stream<List<LeaveDays>> watchCurrentLeave(DateTime today) => _store.watch(
    () => [
      for (final d in _days.values)
        if (!dayOf(d.toDate).isBefore(dayOf(today))) d,
    ],
  );

  @override
  Future<String> submit(
    LeaveDraft draft, {
    required String userId,
    required List<String> approverIds,
    Map<String, String> notify = const {},
    String requesterName = 'A teammate',
  }) async {
    final id = 'preview-leave-${_nextId++}';
    for (final e in notify.entries) {
      if (e.key == userId || !approverIds.contains(e.key)) continue;
      _notify(
        leaveRequestedNotificationId(id, e.key),
        leaveRequestedNotification(
          recipient: e.key,
          requesterUid: userId,
          requesterName: requesterName,
          leaveId: id,
          projectId: e.value,
          detail: leaveNoticeDetail(draft),
        ),
      );
    }
    _requests[id] = LeaveRequest(
      id: id,
      userId: userId,
      type: draft.type,
      fromDate: dayOf(draft.fromDate),
      toDate: dayOf(draft.toDate),
      halfDay: draft.halfDay,
      reason: draft.reason.trim(),
      workingDays: draft.workingDays,
      status: LeaveStatus.pending,
      approverIds: approverIds,
      createdAt: DateTime.now(),
    );
    _store.notify();
    return id;
  }

  @override
  Future<void> cancel(String id) async {
    // Like the rules: only while pending.
    if (_requests[id]?.isPending != true) throw StateError('Not pending');
    _requests.remove(id);
    _store.notify();
  }

  @override
  Future<void> decide(
    LeaveRequest request, {
    required bool approve,
    required String deciderUid,
    required String deciderName,
    required String projectId,
  }) async {
    final current = _requests[request.id];
    if (current == null || !current.isPending) {
      throw StateError('Already decided');
    }
    final decided = LeaveRequest(
      id: current.id,
      userId: current.userId,
      type: current.type,
      fromDate: current.fromDate,
      toDate: current.toDate,
      halfDay: current.halfDay,
      reason: current.reason,
      workingDays: current.workingDays,
      status: approve ? LeaveStatus.approved : LeaveStatus.rejected,
      approverIds: current.approverIds,
      createdAt: current.createdAt,
      decidedBy: deciderUid,
      decidedVia: projectId,
      decidedAt: DateTime.now(),
    );
    _requests[current.id] = decided;
    if (approve) _days[current.id] = _daysOf(decided);
    _notify(
      leaveNotificationId(current.id),
      leaveDecisionNotification(
        current,
        approve: approve,
        deciderUid: deciderUid,
        deciderName: deciderName,
        projectId: projectId,
      ),
    );
    _store.notify();
  }
}
