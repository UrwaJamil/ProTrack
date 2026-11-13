import 'package:cloud_firestore/cloud_firestore.dart';

/// `notifications/{id}.type`. Each type's rule ties the notice to the
/// write that caused it (see `firestore.rules`).
enum NotificationType {
  helpRequested('help_requested'),
  helpAccepted('help_accepted'),
  taskBlocked('task_blocked'),
  commentAdded('comment_added'),
  leaveRequested('leave_requested'),
  leaveApproved('leave_approved'),
  leaveRejected('leave_rejected');

  const NotificationType(this.value);

  final String value;

  /// `null` for a type this app version doesn't know (skipped in lists).
  static NotificationType? tryParse(String? value) {
    for (final t in values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// `notifications/{id}`: written by the sender's app, read and marked
/// read by the recipient ([userId]) only.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.type,
    required this.projectId,
    required this.message,
    required this.read,
    required this.createdAt,
    this.taskId,
    this.leaveId,
    this.commentId,
    this.detail,
  });

  final String id;
  final String userId;
  final String senderId;
  final NotificationType type;
  final String projectId;
  final String? taskId;
  final String? leaveId;
  final String? commentId;
  final String message;

  /// Extra line under the message (a comment's text, a leave's dates, a
  /// blocking reason); optional.
  final String? detail;
  final bool read;
  final DateTime createdAt;

  /// `null` when the type is unknown or a required field is missing.
  static AppNotification? tryParse(
    String id,
    Map<String, dynamic> map, {
    DateTime? now,
  }) {
    final type = NotificationType.tryParse(map['type'] as String?);
    final userId = map['userId'];
    final message = map['message'];
    if (type == null || userId is! String || message is! String) return null;
    final created = map['createdAt'];
    return AppNotification(
      id: id,
      userId: userId,
      senderId: map['senderId'] as String? ?? '',
      type: type,
      projectId: map['projectId'] as String? ?? '',
      taskId: map['taskId'] as String?,
      leaveId: map['leaveId'] as String?,
      commentId: map['commentId'] as String?,
      message: message,
      detail: map['detail'] as String?,
      read: map['read'] as bool? ?? false,
      // A just-written server timestamp is null in the local snapshot.
      createdAt: created is Timestamp
          ? created.toDate()
          : created is DateTime
          ? created
          : now ?? DateTime.now(),
    );
  }
}

/// Clips [s] to [max] characters with an ellipsis, so messages stay
/// within the rules' 200-character limit.
String clipText(String s, int max) {
  final t = s.trim();
  return t.length <= max ? t : '${t.substring(0, max - 1)}…';
}
