import '../../features/leave/data/leave_repository.dart';
import '../../features/leave/data/leave_request.dart';
import '../../features/leave/data/leave_settings.dart';
import '../../features/leave/data/leave_type.dart';
import '../../features/leave/data/working_days.dart';
import 'live_store.dart';

/// In-memory [LeaveRepository] for the dev preview and widget tests.
/// Mirrors the real batches: approving also writes the `leaveDays` entry,
/// and every decision records the requester's notification.
class PreviewLeaveRepository implements LeaveRepository {
  PreviewLeaveRepository({
    List<LeaveRequest> requests = const [],
    this.settings = LeaveSettings.defaults,
  }) {
    for (final r in requests) {
      _requests[r.id] = r;
      if (r.status == LeaveStatus.approved) _days[r.id] = _daysOf(r);
    }
  }

  LeaveSettings settings;
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
  }) async {
    final id = 'preview-leave-${_nextId++}';
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
    notifications[leaveNotificationId(current.id)] = leaveDecisionNotification(
      current,
      approve: approve,
      deciderUid: deciderUid,
      deciderName: deciderName,
      projectId: projectId,
    )..['createdAt'] = DateTime.now();
    _store.notify();
  }
}
