import '../../../core/utils/date_format.dart';
import '../data/leave_request.dart';
import '../data/working_days.dart';

/// Member: the Request Leave form.
const requestLeavePath = '/member/leave/new';

/// Member: one of their requests.
String leaveDetailPath(String leaveId) => '/member/leave/$leaveId';

/// "12 – 14 Nov 2026" style range, or one date for a single day.
String leaveRangeLabel(DateTime from, DateTime to) =>
    dayOf(from) == dayOf(to) ? formatDate(from) : formatDateRange(from, to);

extension LeaveRequestLabels on LeaveRequest {
  String get rangeLabel => leaveRangeLabel(fromDate, toDate);
}
