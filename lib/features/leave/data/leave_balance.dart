import 'leave_request.dart';
import 'leave_settings.dart';
import 'leave_type.dart';

/// The Leave tab's stat tiles and the Request Leave balance check, for
/// one year (Phase 6 decisions, docs/PLAN.md). A request counts in the
/// year its first day falls in.
///
/// - **Used:** approved working days this year, all types.
/// - **Remaining:** what's left of Casual + Sick + Emergency ("Other" has
///   no balance).
/// - **Pending:** working days in pending requests.
class LeaveBalance {
  const LeaveBalance._(
    this.used,
    this.remaining,
    this.pending,
    this._available,
  );

  factory LeaveBalance.compute({
    required Iterable<LeaveRequest> requests,
    required LeaveSettings settings,
    required int year,
  }) {
    num used = 0;
    num pending = 0;
    final approvedByType = <LeaveType, num>{};
    final pendingByType = <LeaveType, num>{};
    for (final r in requests) {
      if (r.fromDate.year != year) continue;
      switch (r.status) {
        case LeaveStatus.approved:
          used += r.workingDays;
          approvedByType[r.type] =
              (approvedByType[r.type] ?? 0) + r.workingDays;
        case LeaveStatus.pending:
          pending += r.workingDays;
          pendingByType[r.type] = (pendingByType[r.type] ?? 0) + r.workingDays;
        case LeaveStatus.rejected:
          break;
      }
    }
    num remaining = 0;
    final available = <LeaveType, num>{};
    for (final type in LeaveType.values.where((t) => t.hasBalance)) {
      final allowance = settings.allowanceFor(type);
      final left = allowance - (approvedByType[type] ?? 0);
      remaining += left < 0 ? 0 : left;
      final free = left - (pendingByType[type] ?? 0);
      available[type] = free < 0 ? 0 : free;
    }
    return LeaveBalance._(used, remaining, pending, available);
  }

  final num used;
  final num remaining;
  final num pending;
  final Map<LeaveType, num> _available;

  /// What a new request of [type] may still use: the allowance minus
  /// approved and pending days of that type. `null` for "Other", which
  /// has no balance.
  num? availableFor(LeaveType type) =>
      type.hasBalance ? _available[type] : null;

  /// Whether a new request of [type] for [days] working days fits.
  bool allows(LeaveType type, num days) {
    final available = availableFor(type);
    return available == null || days <= available;
  }
}
