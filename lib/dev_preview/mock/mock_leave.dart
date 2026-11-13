import '../../features/leave/data/leave_request.dart';
import '../../features/leave/data/leave_type.dart';
import 'mock_people.dart';
import 'mock_projects.dart';

/// Leave from mocks 02 (Ayesha's requests) and 03 (Tariq's pending
/// list), with working days corrected for 2026's calendar (the mock's
/// "12 – 14 Nov · 3 working days" ends on a Saturday, and its
/// "24 – 25 Oct" is a weekend, moved to Oct 22 – 23). Bilal is on approved leave on `mockToday` (Nov 9), so Team and
/// Member Profile show the On Leave badge.
abstract final class MockLeave {
  static final requests = [
    // Ayesha (mock 02).
    _r(
      'ayesha-casual',
      MockPeople.ayesha,
      LeaveType.casual,
      (11, 12),
      (11, 14),
      2,
      'Family event out of town',
      LeaveStatus.pending,
      approvers: [MockPeople.hamza, MockPeople.tariq],
    ),
    _r(
      'ayesha-sick',
      MockPeople.ayesha,
      LeaveType.sick,
      (10, 22),
      (10, 23),
      2,
      'Flu',
      LeaveStatus.approved,
      approvers: [MockPeople.hamza, MockPeople.tariq],
      decidedBy: MockPeople.tariq,
    ),
    _r(
      'ayesha-emergency',
      MockPeople.ayesha,
      LeaveType.emergency,
      (9, 4),
      (9, 4),
      1,
      'Home repair',
      LeaveStatus.rejected,
      approvers: [MockPeople.hamza, MockPeople.tariq],
      decidedBy: MockPeople.tariq,
    ),
    // Tariq's pending list (mock 03).
    _r(
      'hamza-casual',
      MockPeople.hamza,
      LeaveType.casual,
      (11, 12),
      (11, 14),
      2,
      'Attending technical conference',
      LeaveStatus.pending,
    ),
    _r(
      'sara-emergency',
      MockPeople.sara,
      LeaveType.emergency,
      (11, 18),
      (11, 19),
      2,
      'Family medical emergency',
      LeaveStatus.pending,
    ),
    _r(
      'zain-sick',
      MockPeople.zain,
      LeaveType.sick,
      (11, 25),
      (11, 25),
      1,
      'Personal relocation',
      LeaveStatus.pending,
    ),
    // Approved and current: the On Leave badge.
    _r(
      'bilal-casual',
      MockPeople.bilal,
      LeaveType.casual,
      (11, 9),
      (11, 10),
      2,
      'Wedding',
      LeaveStatus.approved,
      decidedBy: MockPeople.tariq,
    ),
  ];

  static LeaveRequest _r(
    String id,
    String userId,
    LeaveType type,
    (int, int) from,
    (int, int) to,
    num days,
    String reason,
    LeaveStatus status, {
    List<String> approvers = const [MockPeople.tariq],
    String? decidedBy,
  }) {
    final created = DateTime(
      2026,
      from.$1,
      from.$2,
    ).subtract(const Duration(days: 7));
    return LeaveRequest(
      id: id,
      userId: userId,
      type: type,
      fromDate: DateTime(2026, from.$1, from.$2),
      toDate: DateTime(2026, to.$1, to.$2),
      halfDay: false,
      reason: reason,
      workingDays: days,
      status: status,
      approverIds: approvers,
      createdAt: created,
      decidedBy: decidedBy,
      decidedVia: decidedBy == null ? null : MockProjects.mobileApp,
      decidedAt: decidedBy == null
          ? null
          : created.add(const Duration(days: 1)),
    );
  }
}
