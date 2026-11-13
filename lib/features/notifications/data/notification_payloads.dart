import 'app_notification.dart';

// `notifications/{id}` payloads for the Phase 8 types, without
// `createdAt` (the writer adds the server timestamp). Each id is fixed per
// cause and recipient, so the rules allow it once. Phase 4 / 6 types keep
// their builders next to their repositories.

/// `comment_<commentId>_<recipient>`.
String commentNotificationId(String commentId, String recipient) =>
    'comment_${commentId}_$recipient';

/// "NAME commented on TASK", with the comment as [detail].
Map<String, dynamic> commentNotification({
  required String recipient,
  required String authorUid,
  required String authorName,
  required String taskTitle,
  required String text,
  required String projectId,
  required String taskId,
  required String commentId,
}) => {
  'userId': recipient,
  'senderId': authorUid,
  'type': NotificationType.commentAdded.value,
  'projectId': projectId,
  'taskId': taskId,
  'commentId': commentId,
  'message':
      '${clipText(authorName, 60)} commented on ${clipText(taskTitle, 100)}',
  'detail': clipText(text, 140),
  'read': false,
};

/// `task_blocked_<requestId>_<recipient>`.
String taskBlockedNotificationId(String requestId, String recipient) =>
    'task_blocked_${requestId}_$recipient';

/// "Task TITLE is blocked", with the blocking reason as [detail].
Map<String, dynamic> taskBlockedNotification({
  required String recipient,
  required String requesterUid,
  required String taskTitle,
  required String reason,
  required String projectId,
  required String taskId,
}) => {
  'userId': recipient,
  'senderId': requesterUid,
  'type': NotificationType.taskBlocked.value,
  'projectId': projectId,
  'taskId': taskId,
  'message': 'Task ${clipText(taskTitle, 100)} is blocked',
  'detail': clipText(reason, 140),
  'read': false,
};

/// `leave_requested_<leaveId>_<recipient>`.
String leaveRequestedNotificationId(String leaveId, String recipient) =>
    'leave_requested_${leaveId}_$recipient';

/// "NAME submitted a leave request", with type and dates as [detail].
/// [projectId] is a project the approver leads and the requester is in.
Map<String, dynamic> leaveRequestedNotification({
  required String recipient,
  required String requesterUid,
  required String requesterName,
  required String leaveId,
  required String projectId,
  required String detail,
}) => {
  'userId': recipient,
  'senderId': requesterUid,
  'type': NotificationType.leaveRequested.value,
  'projectId': projectId,
  'leaveId': leaveId,
  'message': '${clipText(requesterName, 60)} submitted a leave request',
  'detail': clipText(detail, 140),
  'read': false,
};
