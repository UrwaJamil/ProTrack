import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/core/utils/relative_time.dart';
import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/leave/data/leave_repository.dart';
import 'package:team_project_manager/features/leave/data/leave_request.dart';
import 'package:team_project_manager/features/leave/data/leave_type.dart';
import 'package:team_project_manager/features/notifications/application/notification_center_providers.dart';
import 'package:team_project_manager/features/notifications/application/recipients.dart';
import 'package:team_project_manager/features/notifications/data/app_notification.dart';
import 'package:team_project_manager/features/notifications/data/notification_payloads.dart';
import 'package:team_project_manager/features/projects/data/project.dart';

import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

AppNotification _n(
  NotificationType type, {
  String? taskId = 't1',
  String? leaveId,
  String projectId = 'p1',
}) => AppNotification(
  id: 'n1',
  userId: 'u1',
  senderId: 'u2',
  type: type,
  projectId: projectId,
  taskId: taskId,
  leaveId: leaveId,
  message: 'm',
  read: false,
  createdAt: DateTime(2026, 11, 9),
);

void main() {
  group('AppNotification.tryParse', () {
    test('reads every field', () {
      final n = AppNotification.tryParse('c_1', {
        'userId': 'u1',
        'senderId': 'u2',
        'type': 'comment_added',
        'projectId': 'p1',
        'taskId': 't1',
        'commentId': 'c1',
        'message': 'Mo commented on X',
        'detail': 'Hi',
        'read': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 9, 8)),
      })!;
      expect(n.type, NotificationType.commentAdded);
      expect(n.commentId, 'c1');
      expect(n.detail, 'Hi');
      expect(n.read, isTrue);
      expect(n.createdAt, DateTime(2026, 11, 9, 8));
    });

    test('a pending server timestamp falls back to now', () {
      final now = DateTime(2026, 11, 9, 10);
      final n = AppNotification.tryParse('x', {
        'userId': 'u1',
        'type': 'help_accepted',
        'message': 'm',
        'createdAt': null,
      }, now: now)!;
      expect(n.createdAt, now);
      expect(n.read, isFalse);
    });

    test('unknown type or missing fields are skipped', () {
      expect(
        AppNotification.tryParse('x', {
          'userId': 'u1',
          'type': 'task_assigned',
          'message': 'm',
        }),
        isNull,
      );
      expect(AppNotification.tryParse('x', {'type': 'help_accepted'}), isNull);
    });
  });

  group('payloads', () {
    test('ids are fixed per cause and recipient', () {
      expect(commentNotificationId('c1', 'u1'), 'comment_c1_u1');
      expect(taskBlockedNotificationId('r1', 'u1'), 'task_blocked_r1_u1');
      expect(leaveRequestedNotificationId('l1', 'u1'), 'leave_requested_l1_u1');
    });

    test('long text stays within the rules limits', () {
      final long = 'x' * 500;
      final c = commentNotification(
        recipient: 'u1',
        authorUid: 'u2',
        authorName: long,
        taskTitle: long,
        text: long,
        projectId: 'p1',
        taskId: 't1',
        commentId: 'c1',
      );
      expect((c['message'] as String).length, lessThanOrEqualTo(200));
      expect((c['detail'] as String).length, lessThanOrEqualTo(200));
      expect(c['read'], isFalse);
      expect(c.containsKey('createdAt'), isFalse);

      final b = taskBlockedNotification(
        recipient: 'u1',
        requesterUid: 'u2',
        taskTitle: long,
        reason: long,
        projectId: 'p1',
        taskId: 't1',
      );
      expect((b['message'] as String).length, lessThanOrEqualTo(200));
      expect((b['detail'] as String).length, lessThanOrEqualTo(200));
    });

    test('leave_requested has no taskId and names the leave', () {
      final l = leaveRequestedNotification(
        recipient: 'admin',
        requesterUid: 'member1',
        requesterName: 'Mo Member',
        leaveId: 'l1',
        projectId: 'p1',
        detail: 'Casual leave · Nov 12',
      );
      expect(l['message'], 'Mo Member submitted a leave request');
      expect(l['leaveId'], 'l1');
      expect(l.containsKey('taskId'), isFalse);
    });

    test('leaveNoticeDetail: type and dates', () {
      final draft = LeaveDraft(
        type: LeaveType.casual,
        fromDate: DateTime(2026, 11, 12),
        toDate: DateTime(2026, 11, 12),
        halfDay: false,
        reason: 'r',
        workingDays: 1,
      );
      expect(leaveNoticeDetail(draft), startsWith('Casual leave · '));
      expect(leaveNoticeDetail(draft), contains('12'));
    });
  });

  group('recipients', () {
    final project = testProject(
      members: {
        'admin': UserRole.leader,
        'admin2': UserRole.leader,
        'member1': UserRole.member,
        'member2': UserRole.member,
      },
    );

    test('comments: assignees + Admins, minus the author', () {
      final task = testTask(assignedTo: ['member1', 'gone']);
      expect(commentRecipients(project, task, 'member2'), {
        'member1',
        'admin',
        'admin2',
      });
      // Assignee authors: just the Admins.
      expect(commentRecipients(project, task, 'member1'), {'admin', 'admin2'});
      // An Admin author: the assignee and the other Admin.
      expect(commentRecipients(project, task, 'admin'), {'member1', 'admin2'});
    });

    test('blocked: Admins minus requester and helper', () {
      expect(blockedRecipients(project, requesterUid: 'member1'), {
        'admin',
        'admin2',
      });
      expect(
        blockedRecipients(project, requesterUid: 'admin', helperUid: 'admin2'),
        isEmpty,
      );
    });

    test('approverProjects: a shared project the approver leads, active '
        'first', () {
      final archived = testProject(
        id: 'arch',
        status: ProjectStatus.archived,
        members: {'admin': UserRole.leader, 'member1': UserRole.member},
      );
      final other = testProject(
        id: 'other',
        members: {'admin3': UserRole.leader},
      );
      expect(
        approverProjects(
          'member1',
          ['admin', 'admin2', 'admin3'],
          [archived, project, other],
        ),
        {'admin': 'abcd1234', 'admin2': 'abcd1234'},
      );
      expect(approverProjects('member1', ['admin'], [archived]), {
        'admin': 'arch',
      });
    });
  });

  group('notificationTarget', () {
    test('task notices open the task activity for the viewer\'s role', () {
      for (final t in [
        NotificationType.helpRequested,
        NotificationType.helpAccepted,
        NotificationType.taskBlocked,
        NotificationType.commentAdded,
      ]) {
        expect(
          notificationTarget(_n(t), UserRole.leader),
          startsWith('/leader/projects/p1/tasks/t1'),
        );
        expect(
          notificationTarget(_n(t), UserRole.member),
          startsWith('/member/projects/p1/tasks/t1'),
        );
      }
      expect(
        notificationTarget(
          _n(NotificationType.commentAdded, taskId: null),
          UserRole.member,
        ),
        isNull,
      );
    });

    test('leave notices open the matching dashboard only', () {
      final requested = _n(
        NotificationType.leaveRequested,
        taskId: null,
        leaveId: 'l1',
      );
      expect(notificationTarget(requested, UserRole.leader), '/leader/leave');
      expect(notificationTarget(requested, UserRole.member), isNull);

      final approved = _n(
        NotificationType.leaveApproved,
        taskId: null,
        leaveId: 'l1',
      );
      expect(notificationTarget(approved, UserRole.member), '/member/leave/l1');
      expect(notificationTarget(approved, UserRole.leader), isNull);
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 11, 9, 10);
    String f(Duration d) => formatRelativeTime(now.subtract(d), now: now);

    test('minutes, hours, yesterday, days, then a date', () {
      expect(f(const Duration(seconds: 20)), 'Just now');
      expect(f(const Duration(minutes: 12)), '12m ago');
      expect(f(const Duration(hours: 3)), '3h ago');
      expect(f(const Duration(hours: 12)), 'Yesterday');
      expect(f(const Duration(days: 3)), '3d ago');
      expect(f(const Duration(days: 18)), isNot(contains('ago')));
    });
  });
}
