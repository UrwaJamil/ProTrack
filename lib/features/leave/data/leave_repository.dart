import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../auth/data/user_repository.dart';
import 'leave_request.dart';
import 'leave_settings.dart';
import 'leave_type.dart';
import 'working_days.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(firestoreProvider)),
);

/// Upper bound on the current-leave query (`leaveDays` list rule).
const currentLeaveLimit = 200;

/// Leave requests, their public `leaveDays` mirror and `settings/leave`
/// (Phase 6). Permissions are enforced by Firestore rules.
class LeaveRepository {
  LeaveRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('leaveRequests');

  CollectionReference<Map<String, dynamic>> get _days =>
      _firestore.collection('leaveDays');

  static List<LeaveRequest> _parseAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => [for (final doc in docs) ?_tryParse(doc.id, doc.data())];

  static LeaveRequest? _tryParse(String id, Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      return LeaveRequest.fromMap(id, map);
    } on FormatException {
      return null;
    }
  }

  /// The signed-in user's own requests (any order; sorted in the app).
  Stream<List<LeaveRequest>> watchMine(String uid) => _requests
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => _parseAll(snap.docs));

  /// Requests [uid] may decide (pending) or did see (history). One
  /// array-contains query with no status filter, so no composite index.
  Stream<List<LeaveRequest>> watchForApprover(String uid) => _requests
      .where('approverIds', arrayContains: uid)
      .snapshots()
      .map((snap) => _parseAll(snap.docs));

  /// One request, live; `null` once cancelled (deleted) or never existed.
  Stream<LeaveRequest?> watchRequest(String id) =>
      _requests.doc(id).snapshots().map((doc) => _tryParse(doc.id, doc.data()));

  /// `settings/leave`, or [LeaveSettings.defaults] while the doc is
  /// missing.
  Stream<LeaveSettings> watchSettings() => _firestore
      .collection('settings')
      .doc('leave')
      .snapshots()
      .map((doc) => LeaveSettings.fromMap(doc.data()));

  /// Approved leave that hasn't ended before [today]. Filtered by start
  /// date in the app (one range filter per query).
  Stream<List<LeaveDays>> watchCurrentLeave(DateTime today) => _days
      .where('toDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dayOf(today)))
      .limit(currentLeaveLimit)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs) LeaveDays.fromMap(doc.id, doc.data()),
        ],
      );

  /// Creates a pending request. [approverIds] must not be empty (the form
  /// blocks with "No approver available" first).
  Future<String> submit(
    LeaveDraft draft, {
    required String userId,
    required List<String> approverIds,
  }) async {
    final doc = _requests.doc();
    await doc.set({
      ...draft.toMap(userId: userId, approverIds: approverIds),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Requester, while pending (rules).
  Future<void> cancel(String id) => _requests.doc(id).delete();

  /// Approve or reject, in one batch:
  /// - the request: `status`, `decidedBy`, `decidedVia` ([projectId], a
  ///   project the decider leads and the requester is in), `decidedAt`;
  /// - when approving, `leaveDays/{id}` (who and when only);
  /// - the requester's notification at `leave_<id>`.
  Future<void> decide(
    LeaveRequest request, {
    required bool approve,
    required String deciderUid,
    required String deciderName,
    required String projectId,
  }) {
    final status = approve ? LeaveStatus.approved : LeaveStatus.rejected;
    final batch = _firestore.batch()
      ..update(_requests.doc(request.id), {
        'status': status.value,
        'decidedBy': deciderUid,
        'decidedVia': projectId,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    if (approve) {
      batch.set(_days.doc(request.id), {
        'userId': request.userId,
        'fromDate': Timestamp.fromDate(request.fromDate),
        'toDate': Timestamp.fromDate(request.toDate),
      });
    }
    batch.set(
      _firestore
          .collection('notifications')
          .doc(leaveNotificationId(request.id)),
      leaveDecisionNotification(
        request,
        approve: approve,
        deciderUid: deciderUid,
        deciderName: deciderName,
        projectId: projectId,
      )..['createdAt'] = FieldValue.serverTimestamp(),
    );
    return batch.commit();
  }
}

/// The fixed `notifications/{id}` of a leave decision.
String leaveNotificationId(String leaveId) => 'leave_$leaveId';

/// `notifications/{nid}` telling the requester about the decision,
/// without `createdAt`. The message stays within the rules' 200
/// characters.
Map<String, dynamic> leaveDecisionNotification(
  LeaveRequest request, {
  required bool approve,
  required String deciderUid,
  required String deciderName,
  required String projectId,
}) {
  final name = deciderName.length <= 60
      ? deciderName
      : '${deciderName.substring(0, 59)}…';
  final range = request.fromDate == request.toDate
      ? formatDate(request.fromDate)
      : formatDateRange(request.fromDate, request.toDate);
  return {
    'userId': request.userId,
    'senderId': deciderUid,
    'type': approve ? 'leave_approved' : 'leave_rejected',
    'projectId': projectId,
    'leaveId': request.id,
    'message':
        '$name ${approve ? 'approved' : 'rejected'} your '
        '${request.type.label} leave ($range)',
    'read': false,
  };
}
