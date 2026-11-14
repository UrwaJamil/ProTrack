/// `leaveRequests/{id}.type`. Stored values are lower-case; the UI shows
/// [label].
enum LeaveType {
  sick('sick', 'Sick'),
  casual('casual', 'Casual'),
  emergency('emergency', 'Emergency'),
  other('other', 'Other');

  const LeaveType(this.value, this.label);

  final String value;
  final String label;

  /// Types with a yearly allowance in `settings/leave`. "Other" has none
  /// and is never blocked for balance (Phase 6 decision).
  bool get hasBalance => this != LeaveType.other;

  static LeaveType fromValue(String? value) => LeaveType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => throw FormatException('Unknown leave type: "$value"'),
  );
}

/// `leaveRequests/{id}.status`. Cancelling a pending request deletes it,
/// so there's no "cancelled" value.
enum LeaveStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const LeaveStatus(this.value, this.label);

  final String value;
  final String label;

  static LeaveStatus fromValue(String? value) => LeaveStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => throw FormatException('Unknown leave status: "$value"'),
  );
}
