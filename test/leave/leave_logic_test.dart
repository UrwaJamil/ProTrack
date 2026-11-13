import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/leave/application/approvers.dart';
import 'package:team_project_manager/features/leave/application/leave_validation.dart';
import 'package:team_project_manager/features/leave/data/leave_balance.dart';
import 'package:team_project_manager/features/leave/data/leave_repository.dart';
import 'package:team_project_manager/features/leave/data/leave_request.dart';
import 'package:team_project_manager/features/leave/data/leave_settings.dart';
import 'package:team_project_manager/features/leave/data/leave_type.dart';
import 'package:team_project_manager/features/leave/data/working_days.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

LeaveRequest _req({
  String id = 'l1',
  String userId = 'm1',
  LeaveType type = LeaveType.casual,
  DateTime? from,
  DateTime? to,
  num days = 2,
  LeaveStatus status = LeaveStatus.pending,
}) => LeaveRequest(
  id: id,
  userId: userId,
  type: type,
  fromDate: from ?? DateTime(2026, 11, 12),
  toDate: to ?? DateTime(2026, 11, 13),
  halfDay: false,
  reason: 'r',
  workingDays: days,
  status: status,
  approverIds: const ['admin'],
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  group('workingDaysBetween', () {
    // Nov 2026: 9 = Monday, 14/15 = weekend.
    test('counts Monday–Friday, both ends included', () {
      expect(
        workingDaysBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 13)),
        5,
      );
      expect(
        workingDaysBetween(DateTime(2026, 11, 12), DateTime(2026, 11, 14)),
        2,
      );
      expect(
        workingDaysBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 22)),
        10,
      );
    });

    test('a weekend-only range has none; a reversed range has none', () {
      expect(
        workingDaysBetween(DateTime(2026, 11, 14), DateTime(2026, 11, 15)),
        0,
      );
      expect(
        workingDaysBetween(DateTime(2026, 11, 13), DateTime(2026, 11, 9)),
        0,
      );
    });

    test('skips holidays, ignoring the time of day', () {
      expect(
        workingDaysBetween(
          DateTime(2026, 12, 21),
          DateTime(2026, 12, 25),
          holidays: {DateTime(2026, 12, 25, 15)},
        ),
        4,
      );
    });

    test('a half day counts 0.5, only for a single working day', () {
      final d = DateTime(2026, 11, 12);
      expect(workingDaysBetween(d, d, halfDay: true), 0.5);
      expect(workingDaysBetween(d, DateTime(2026, 11, 13), halfDay: true), 2);
      final sat = DateTime(2026, 11, 14);
      expect(workingDaysBetween(sat, sat, halfDay: true), 0);
    });

    test('calendar days and labels', () {
      expect(
        calendarDaysBetween(DateTime(2026, 11, 12), DateTime(2026, 11, 14)),
        3,
      );
      expect(workingDaysLabel(1), '1 working day');
      expect(workingDaysLabel(0.5), '0.5 working day');
      expect(workingDaysLabel(3), '3 working days');
      expect(formatDays(8.5), '8.5');
    });
  });

  group('LeaveSettings', () {
    test('missing doc → defaults', () {
      final s = LeaveSettings.fromMap(null);
      expect(s.allowanceFor(LeaveType.casual), 10);
      expect(s.allowanceFor(LeaveType.sick), 8);
      expect(s.allowanceFor(LeaveType.emergency), 3);
      expect(s.allowanceFor(LeaveType.other), 0);
    });

    test('reads allowances and YYYY-MM-DD holidays, ignoring bad values', () {
      final s = LeaveSettings.fromMap({
        'allowances': {'casual': 12, 'sick': 'x', 'emergency': -1},
        'holidays': ['2026-12-25', 'nope', 7],
      });
      expect(s.allowanceFor(LeaveType.casual), 12);
      expect(s.allowanceFor(LeaveType.sick), 8);
      expect(s.allowanceFor(LeaveType.emergency), 3);
      expect(s.holidays, {DateTime(2026, 12, 25)});
    });
  });

  group('LeaveBalance', () {
    final balance = LeaveBalance.compute(
      year: 2026,
      settings: LeaveSettings.defaults,
      requests: [
        _req(id: 'a', days: 3, status: LeaveStatus.approved),
        _req(
          id: 'b',
          type: LeaveType.sick,
          days: 2,
          status: LeaveStatus.approved,
        ),
        _req(
          id: 'c',
          type: LeaveType.other,
          days: 4,
          status: LeaveStatus.approved,
        ),
        _req(id: 'd', days: 1.5),
        _req(id: 'e', days: 9, status: LeaveStatus.rejected),
        // Last year: ignored.
        _req(
          id: 'f',
          days: 5,
          status: LeaveStatus.approved,
          from: DateTime(2025, 12, 1),
          to: DateTime(2025, 12, 5),
        ),
      ],
    );

    test('Used = approved days this year, all types', () {
      expect(balance.used, 9);
    });

    test('Remaining = what is left of Casual + Sick + Emergency', () {
      // (10 - 3) + (8 - 2) + 3
      expect(balance.remaining, 16);
    });

    test('Pending = days in pending requests', () {
      expect(balance.pending, 1.5);
    });

    test('available per type subtracts approved and pending', () {
      expect(balance.availableFor(LeaveType.casual), 5.5);
      expect(balance.availableFor(LeaveType.sick), 6);
      expect(balance.availableFor(LeaveType.other), isNull);
      expect(balance.allows(LeaveType.casual, 5.5), isTrue);
      expect(balance.allows(LeaveType.casual, 6), isFalse);
      expect(balance.allows(LeaveType.other, 100), isTrue);
    });
  });

  group('leaveBlockReason', () {
    final balance = LeaveBalance.compute(
      year: 2026,
      settings: LeaveSettings.defaults,
      requests: const [],
    );
    String? reason({
      List<String> approvers = const ['admin'],
      LeaveType type = LeaveType.emergency,
      DateTime? from,
      DateTime? to,
      num days = 1,
    }) => leaveBlockReason(
      approverIds: approvers,
      balance: balance,
      type: type,
      from: from ?? DateTime(2026, 11, 12),
      to: to ?? DateTime(2026, 11, 12),
      workingDays: days,
    );

    test('no approver blocks first', () {
      expect(reason(approvers: const []), noApproverMessage);
    });

    test('over balance blocks, Other never does', () {
      expect(reason(days: 4), contains('Only 3 Emergency days'));
      expect(reason(type: LeaveType.other, days: 40), isNull);
      expect(reason(days: 3), isNull);
    });

    test('reversed dates and no working days block', () {
      expect(
        reason(from: DateTime(2026, 11, 13), to: DateTime(2026, 11, 12)),
        contains("can't be before"),
      );
      expect(reason(days: 0), 'These dates have no working days.');
    });
  });

  group('approvers', () {
    final p1 = testProject(
      id: 'p1',
      members: {'admin': UserRole.leader, 'm1': UserRole.member},
    );
    final p2 = testProject(
      id: 'p2',
      createdBy: 'admin2',
      members: {
        'admin2': UserRole.leader,
        'admin': UserRole.leader,
        'm1': UserRole.member,
      },
    );
    final archived = testProject(
      id: 'p3',
      createdBy: 'admin3',
      status: ProjectStatus.archived,
      members: {'admin3': UserRole.leader, 'm1': UserRole.member},
    );
    final other = testProject(
      id: 'p4',
      createdBy: 'admin4',
      members: {'admin4': UserRole.leader, 'm2': UserRole.member},
    );

    test('leaders of my active projects, minus me, sorted', () {
      expect(approverIdsFor('m1', [p1, p2, archived, other]), [
        'admin',
        'admin2',
      ]);
      expect(approverIdsFor('admin', [p1, p2]), ['admin2']);
      expect(approverIdsFor('m9', [p1]), isEmpty);
    });

    test('the deciding project: one I lead that the requester is in', () {
      expect(decidingProjectFor('admin', 'm1', [p1, p2])?.id, 'p1');
      expect(decidingProjectFor('admin2', 'm1', [p1, p2])?.id, 'p2');
      expect(decidingProjectFor('admin4', 'm1', [other]), isNull);
      expect(decidingProjectFor('m1', 'admin', [p1]), isNull);
      // Falls back to an archived one only when nothing active is shared.
      expect(decidingProjectFor('admin3', 'm1', [archived])?.id, 'p3');
    });

    test('tasks due during the leave: open, mine, deadline in range', () {
      final tasks = [
        testTask(
          id: 'in',
          assignedTo: ['m1'],
          deadline: DateTime(2026, 11, 13, 18),
        ),
        testTask(
          id: 'edge',
          assignedTo: ['m1'],
          deadline: DateTime(2026, 11, 12),
        ),
        testTask(
          id: 'done',
          assignedTo: ['m1'],
          deadline: DateTime(2026, 11, 13),
          status: TaskStatus.completed,
        ),
        testTask(
          id: 'other',
          assignedTo: ['m2'],
          deadline: DateTime(2026, 11, 13),
        ),
        testTask(
          id: 'after',
          assignedTo: ['m1'],
          deadline: DateTime(2026, 11, 14),
        ),
      ];
      expect(
        tasksDueDuring(
          tasks,
          uid: 'm1',
          from: DateTime(2026, 11, 12),
          to: DateTime(2026, 11, 13),
        ).map((t) => t.id),
        ['edge', 'in'],
      );
    });
  });

  group('LeaveRequest / draft / notification', () {
    test('draft payload and round trip', () {
      final map = LeaveDraft(
        type: LeaveType.sick,
        fromDate: DateTime(2026, 11, 12, 15),
        toDate: DateTime(2026, 11, 12, 9),
        halfDay: true,
        reason: '  Dentist ',
        workingDays: 0.5,
      ).toMap(userId: 'm1', approverIds: ['admin']);
      expect(map['type'], 'sick');
      expect(map['fromDate'], Timestamp.fromDate(DateTime(2026, 11, 12)));
      expect(map['reason'], 'Dentist');
      expect(map['status'], 'pending');
      expect(map.containsKey('createdAt'), isFalse);

      final r = LeaveRequest.fromMap('l1', {
        ...map,
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 1)),
      });
      expect(r.type, LeaveType.sick);
      expect(r.workingDays, 0.5);
      expect(r.isPending, isTrue);
      expect(r.covers(DateTime(2026, 11, 12, 23)), isTrue);
      expect(r.covers(DateTime(2026, 11, 13)), isFalse);
    });

    test('unknown type or status is rejected', () {
      expect(() => LeaveType.fromValue('vacation'), throwsFormatException);
      expect(() => LeaveStatus.fromValue('cancelled'), throwsFormatException);
    });

    test('decision notification', () {
      final n = leaveDecisionNotification(
        _req(),
        approve: false,
        deciderUid: 'admin',
        deciderName: 'Ada Admin',
        projectId: 'p1',
      );
      expect(n, {
        'userId': 'm1',
        'senderId': 'admin',
        'type': 'leave_rejected',
        'projectId': 'p1',
        'leaveId': 'l1',
        'message':
            'Ada Admin rejected your Casual leave (Nov 12 – Nov 13, 2026)',
        'read': false,
      });
      expect(leaveNotificationId('l1'), 'leave_l1');
      final long = leaveDecisionNotification(
        _req(),
        approve: true,
        deciderUid: 'admin',
        deciderName: 'N' * 300,
        projectId: 'p1',
      );
      expect((long['message'] as String).length, lessThanOrEqualTo(200));
    });
  });
}
