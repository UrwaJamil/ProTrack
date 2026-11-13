import 'package:cloud_firestore/cloud_firestore.dart';

import 'leave_type.dart';
import 'working_days.dart';

/// `leaveRequests/{id}`. Readable by the requester and the people in
/// [approverIds] only, because it holds the reason. Teammates see who is
/// on leave through [LeaveDays] instead.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.halfDay,
    required this.reason,
    required this.workingDays,
    required this.status,
    required this.approverIds,
    required this.createdAt,
    this.decidedBy,
    this.decidedVia,
    this.decidedAt,
  });

  final String id;
  final String userId;
  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final bool halfDay;
  final String reason;

  /// Working days at submit time ([workingDaysBetween]).
  final num workingDays;
  final LeaveStatus status;

  /// Leaders of the requester's projects at submit time, minus the
  /// requester. Lets approvers list the request.
  final List<String> approverIds;
  final DateTime createdAt;
  final String? decidedBy;

  /// The project through which the decider leads the requester; the rules
  /// check it.
  final String? decidedVia;
  final DateTime? decidedAt;

  bool get isPending => status == LeaveStatus.pending;

  /// Whether the leave covers [day].
  bool covers(DateTime day) {
    final d = dayOf(day);
    return !d.isBefore(dayOf(fromDate)) && !d.isAfter(dayOf(toDate));
  }

  factory LeaveRequest.fromMap(String id, Map<String, dynamic> map) =>
      LeaveRequest(
        id: id,
        userId: map['userId'] as String? ?? '',
        type: LeaveType.fromValue(map['type'] as String?),
        fromDate: _date(map['fromDate']),
        toDate: _date(map['toDate']),
        halfDay: map['halfDay'] as bool? ?? false,
        reason: map['reason'] as String? ?? '',
        workingDays: map['workingDays'] as num? ?? 0,
        status: LeaveStatus.fromValue(map['status'] as String?),
        approverIds: List<String>.from(map['approverIds'] as List? ?? const []),
        createdAt: _date(map['createdAt'], fallback: DateTime.now()),
        decidedBy: map['decidedBy'] as String?,
        decidedVia: map['decidedVia'] as String?,
        decidedAt: map['decidedAt'] == null ? null : _date(map['decidedAt']),
      );

  static DateTime _date(Object? value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (fallback != null) return fallback;
    throw const FormatException('Missing leave date');
  }
}

/// What the Request Leave form submits.
class LeaveDraft {
  const LeaveDraft({
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.halfDay,
    required this.reason,
    required this.workingDays,
  });

  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final bool halfDay;
  final String reason;
  final num workingDays;

  /// The create payload, without `createdAt` (the repository adds the
  /// server timestamp).
  Map<String, dynamic> toMap({
    required String userId,
    required List<String> approverIds,
  }) => {
    'userId': userId,
    'type': type.value,
    'fromDate': Timestamp.fromDate(dayOf(fromDate)),
    'toDate': Timestamp.fromDate(dayOf(toDate)),
    'halfDay': halfDay,
    'reason': reason.trim(),
    'workingDays': workingDays,
    'status': LeaveStatus.pending.value,
    'approverIds': approverIds,
  };
}

/// `leaveDays/{id}` (same id as the request): only who and when, written
/// in the approval batch. Any signed-in user may read it, so the On Leave
/// badge can be computed on read without exposing the reason.
class LeaveDays {
  const LeaveDays({
    required this.id,
    required this.userId,
    required this.fromDate,
    required this.toDate,
  });

  final String id;
  final String userId;
  final DateTime fromDate;
  final DateTime toDate;

  bool covers(DateTime day) {
    final d = dayOf(day);
    return !d.isBefore(dayOf(fromDate)) && !d.isAfter(dayOf(toDate));
  }

  factory LeaveDays.fromMap(String id, Map<String, dynamic> map) => LeaveDays(
    id: id,
    userId: map['userId'] as String? ?? '',
    fromDate: LeaveRequest._date(map['fromDate']),
    toDate: LeaveRequest._date(map['toDate']),
  );
}
