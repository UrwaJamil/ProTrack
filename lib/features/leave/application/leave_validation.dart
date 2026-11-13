import '../data/leave_balance.dart';
import '../data/leave_type.dart';
import '../data/working_days.dart';

const noApproverMessage = 'No approver available. Contact your admin.';

/// Why the Request Leave form can't be sent right now, or `null` when it
/// can (Phase 6 decisions). Missing fields are left to the form's own
/// validators; this covers the rules that need the balance and approvers.
String? leaveBlockReason({
  required List<String> approverIds,
  required LeaveBalance balance,
  required LeaveType type,
  required DateTime? from,
  required DateTime? to,
  required num workingDays,
}) {
  if (approverIds.isEmpty) return noApproverMessage;
  if (from == null || to == null) return null;
  if (dayOf(to).isBefore(dayOf(from))) {
    return "The end date can't be before the start date.";
  }
  if (workingDays <= 0) return 'These dates have no working days.';
  if (!balance.allows(type, workingDays)) {
    final left = balance.availableFor(type) ?? 0;
    return 'Only ${formatDays(left)} ${type.label} '
        '${left == 1 ? 'day is' : 'days are'} available this year. '
        'Shorten the request or pick another type.';
  }
  return null;
}
