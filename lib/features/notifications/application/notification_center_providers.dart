import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../../tasks/presentation/task_activity_paths.dart';
import '../data/app_notification.dart';
import '../data/notification_repository.dart';

/// The signed-in user's newest notifications (server-sorted).
final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchMine(uid);
});

/// Unread count for the bell's dot (through the approved
/// `unreadNotificationCountProvider` stub).
final myUnreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});

/// Which dashboard's routes a notification opens in: the user's default
/// role (the router keeps Members off `/leader/...`).
final notificationRoleProvider = Provider<UserRole>(
  (ref) =>
      ref.watch(authControllerProvider.select((s) => s.profile?.defaultRole)) ??
      UserRole.member,
);

/// Where tapping [n] goes, or `null` when there's nothing to open for
/// [role] (e.g. a leave notice on the other dashboard).
String? notificationTarget(AppNotification n, UserRole role) {
  final admin = role == UserRole.leader;
  final taskId = n.taskId;
  final leaveId = n.leaveId;
  switch (n.type) {
    case NotificationType.helpRequested:
    case NotificationType.helpAccepted:
    case NotificationType.taskBlocked:
    case NotificationType.commentAdded:
      if (taskId == null || n.projectId.isEmpty) return null;
      return taskActivityPath(n.projectId, taskId, adminView: admin);
    case NotificationType.leaveRequested:
      return admin ? '/leader/leave' : null;
    case NotificationType.leaveApproved:
    case NotificationType.leaveRejected:
      if (admin || leaveId == null) return null;
      return '/member/leave/$leaveId';
  }
}
