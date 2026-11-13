import '../../core/utils/date_format.dart';
import '../../features/leave/data/leave_repository.dart';
import '../../features/notifications/data/notification_payloads.dart';
import '../../features/tasks/data/task_activity_repository.dart';
import 'mock_leave.dart';
import 'mock_people.dart';
import 'mock_projects.dart';
import 'mock_tasks.dart';

/// Notices from the notification mocks: Tariq's (03, Admin) and
/// Ayesha's (01, Member). Built with the real payload builders, so the
/// messages match what the app writes. Times are relative to `mockToday`.
abstract final class MockNotifications {
  static DateTime _ago(Duration d) => mockToday.subtract(d);

  static Map<String, dynamic> _at(
    Map<String, dynamic> data,
    Duration ago, {
    bool read = false,
  }) => {...data, 'createdAt': _ago(ago), 'read': read};

  static final all = <String, Map<String, dynamic>>{
    // Tariq (Admin).
    leaveRequestedNotificationId('hamza-casual', MockPeople.tariq): _at(
      leaveRequestedNotification(
        recipient: MockPeople.tariq,
        requesterUid: MockPeople.hamza,
        requesterName: 'Hamza Farooq',
        leaveId: 'hamza-casual',
        projectId: MockProjects.mobileApp,
        detail:
            'Casual leave · '
            '${formatDateRange(DateTime(2026, 11, 12), DateTime(2026, 11, 14))}',
      ),
      const Duration(minutes: 12),
    ),
    taskBlockedNotificationId('mock-blocked', MockPeople.tariq): _at(
      taskBlockedNotification(
        recipient: MockPeople.tariq,
        requesterUid: MockPeople.zain,
        taskTitle: 'Set up Firestore security rules',
        reason: 'Waiting on the emulator test setup (Java 21).',
        projectId: MockProjects.cloudMigration,
        taskId: MockTasks.firestoreRules,
      ),
      const Duration(hours: 2),
    ),
    commentNotificationId('mock-c1', MockPeople.tariq): _at(
      commentNotification(
        recipient: MockPeople.tariq,
        authorUid: MockPeople.ayesha,
        authorName: 'Ayesha Noor',
        taskTitle: 'Design login flow',
        text: 'Uploaded the dark mode pass for review.',
        projectId: MockProjects.mobileApp,
        taskId: MockTasks.designLogin,
        commentId: 'mock-c1',
      ),
      const Duration(days: 1, hours: 2),
      read: true,
    ),

    // Ayesha (Member).
    commentNotificationId('mock-c2', MockPeople.ayesha): _at(
      commentNotification(
        recipient: MockPeople.ayesha,
        authorUid: MockPeople.hamza,
        authorName: 'Hamza Farooq',
        taskTitle: 'Design login flow',
        text: "Looks great, let's update the mobile tokens too.",
        projectId: MockProjects.mobileApp,
        taskId: MockTasks.designLogin,
        commentId: 'mock-c2',
      ),
      const Duration(minutes: 25),
    ),
    'help_accepted_mock-h2': _at(
      helpAcceptedNotification(
        requesterUid: MockPeople.ayesha,
        helperUid: MockPeople.zain,
        helperName: 'Zain Ahmed',
        projectId: MockProjects.mobileApp,
        taskId: MockTasks.designLogin,
      ),
      const Duration(hours: 3),
    ),
    helpRequestedNotificationId('mock-h3'): _at(
      helpRequestedNotification(
        helperUid: MockPeople.ayesha,
        requesterUid: MockPeople.hamza,
        requesterName: 'Hamza Farooq',
        taskTitle: 'Color tokens',
        projectId: MockProjects.designSystem,
        taskId: 'tok8tokens',
      ),
      const Duration(days: 1, hours: 1),
      read: true,
    ),
    leaveNotificationId('ayesha-sick'): _at(
      leaveDecisionNotification(
        MockLeave.requests.firstWhere((r) => r.id == 'ayesha-sick'),
        approve: true,
        deciderUid: MockPeople.tariq,
        deciderName: 'Tariq Khan',
        projectId: MockProjects.mobileApp,
      ),
      const Duration(days: 18),
      read: true,
    ),
  };
}
