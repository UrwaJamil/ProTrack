import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import '../../notifications/data/notification_payloads.dart';
import 'help_note.dart';
import 'task_comment.dart';
import 'task_history_entry.dart';
import 'task_status.dart';

final taskActivityRepositoryProvider = Provider<TaskActivityRepository>(
  (ref) => TaskActivityRepository(ref.watch(firestoreProvider)),
);

/// A task's comments and history subcollections (CLAUDE.md decision 5)
/// plus the help request (Phase 4). A new code path next to the existing
/// `TaskRepository`, which stays untouched. Permissions are enforced by
/// Firestore rules.
class TaskActivityRepository {
  TaskActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _task(
    String projectId,
    String taskId,
  ) => _firestore
      .collection('projects')
      .doc(projectId)
      .collection('tasks')
      .doc(taskId);

  CollectionReference<Map<String, dynamic>> _comments(
    String projectId,
    String taskId,
  ) => _task(projectId, taskId).collection('comments');

  CollectionReference<Map<String, dynamic>> _history(
    String projectId,
    String taskId,
  ) => _task(projectId, taskId).collection('history');

  // ------------------------------------------------------------ comments

  /// Oldest first, like a chat.
  Stream<List<TaskComment>> watchComments(String projectId, String taskId) =>
      _comments(projectId, taskId)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                TaskComment.fromMap(doc.id, doc.data()),
            ],
          );

  /// Phase 8: in the same batch, a `comment_added` notice for each of
  /// [recipients] except the author (assignees + project Admins; see
  /// `commentRecipients`).
  Future<void> addComment(
    String projectId,
    String taskId, {
    required String authorId,
    required String text,
    String authorName = 'A teammate',
    String taskTitle = 'a task',
    Iterable<String> recipients = const [],
  }) {
    final comment = _comments(projectId, taskId).doc();
    final batch = _firestore.batch()
      ..set(comment, {
        'authorId': authorId,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final r in {...recipients}..remove(authorId)) {
      batch.set(
        _firestore
            .collection('notifications')
            .doc(commentNotificationId(comment.id, r)),
        commentNotification(
          recipient: r,
          authorUid: authorId,
          authorName: authorName,
          taskTitle: taskTitle,
          text: text,
          projectId: projectId,
          taskId: taskId,
          commentId: comment.id,
        )..['createdAt'] = FieldValue.serverTimestamp(),
      );
    }
    return batch.commit();
  }

  /// Author only (rules).
  Future<void> editComment(
    String projectId,
    String taskId,
    String commentId,
    String text,
  ) => _comments(projectId, taskId).doc(commentId).update({
    'text': text.trim(),
    'editedAt': FieldValue.serverTimestamp(),
  });

  /// Author or project Admin (rules).
  Future<void> deleteComment(
    String projectId,
    String taskId,
    String commentId,
  ) => _comments(projectId, taskId).doc(commentId).delete();

  // ------------------------------------------------------------- history

  /// Newest first, at most [limit] entries ("Load more" raises it).
  /// Entries with an unknown action are skipped rather than failing the
  /// list.
  Stream<List<TaskHistoryEntry>> watchHistory(
    String projectId,
    String taskId, {
    required int limit,
  }) => _history(projectId, taskId)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs) ?_tryHistory(doc.id, doc.data()),
        ],
      );

  static TaskHistoryEntry? _tryHistory(String id, Map<String, dynamic> map) {
    try {
      return TaskHistoryEntry.fromMap(id, map);
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------- help note

  /// The task's current help note, or `null` when it has none.
  Stream<HelpNote?> watchHelpNote(String projectId, String taskId) => _task(
    projectId,
    taskId,
  ).snapshots().map((doc) => HelpNote.fromField(doc.data()?['helpNote']));

  /// Need Help: sets the task to Blocked with the help note and records a
  /// `help_requested` history entry (from = previous status, to = the
  /// helper's uid), in one batch so neither lands without the other. The
  /// entry's id is stored as `helpNote.requestId`, so the helper's accept
  /// can be tied to this request. The task write only touches `status`,
  /// `helpNote` and `updatedAt`, which the rules let an assignee change.
  /// When a helper is named, the same batch also writes their
  /// notification ("NAME requested your help on TASK") at
  /// `help_requested_<requestId>`.
  Future<void> requestHelp(
    String projectId,
    String taskId, {
    required String requesterUid,
    required String requesterName,
    required String taskTitle,
    required TaskStatus previousStatus,
    required HelpNote note,
    Iterable<String> adminIds = const [],
  }) {
    final entry = _history(projectId, taskId).doc();
    final helperUid = note.taggedUserId;
    final batch = _firestore.batch();
    // Phase 8: "Task X is blocked" for the project's Admins (decision C),
    // never the requester or the named helper.
    for (final admin in {...adminIds}
      ..remove(requesterUid)
      ..remove(helperUid)) {
      batch.set(
        _firestore
            .collection('notifications')
            .doc(taskBlockedNotificationId(entry.id, admin)),
        taskBlockedNotification(
          recipient: admin,
          requesterUid: requesterUid,
          taskTitle: taskTitle,
          reason: note.text,
          projectId: projectId,
          taskId: taskId,
        )..['createdAt'] = FieldValue.serverTimestamp(),
      );
    }
    if (helperUid != null) {
      batch.set(
        _firestore
            .collection('notifications')
            .doc(helpRequestedNotificationId(entry.id)),
        helpRequestedNotification(
          helperUid: helperUid,
          requesterUid: requesterUid,
          requesterName: requesterName,
          taskTitle: taskTitle,
          projectId: projectId,
          taskId: taskId,
        )..['createdAt'] = FieldValue.serverTimestamp(),
      );
    }
    batch
      ..update(_task(projectId, taskId), {
        'status': TaskStatus.blocked.value,
        'helpNote': note.withRequestId(entry.id).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(entry, {
        'who': requesterUid,
        'action': HistoryAction.helpRequested.value,
        'from': previousStatus.value,
        if (note.taggedUserId != null) 'to': note.taggedUserId,
        'at': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }

  /// Whether the request [requestId] was already accepted.
  Stream<bool> watchAccepted(
    String projectId,
    String taskId,
    String requestId,
  ) => _history(
    projectId,
    taskId,
  ).doc(acceptEntryId(requestId)).snapshots().map((doc) => doc.exists);

  /// The helper named in [note] accepts the request: in one batch, the
  /// `help_accepted` history entry (at `accept_<requestId>`, to = the
  /// requester) and a notification for the requester ("NAME accepted
  /// your help request"), at `help_accepted_<requestId>`. The rules allow
  /// each once, only for that helper, and only to the real requester (the
  /// writer of the `help_requested` entry, read here first). Doesn't
  /// change the task.
  Future<void> acceptHelp(
    String projectId,
    String taskId, {
    required String helperUid,
    required String helperName,
    required HelpNote note,
  }) async {
    final requestId = note.requestId;
    if (requestId == null || requestId.isEmpty) {
      throw StateError('This help request cannot be accepted.');
    }
    final request = await _history(projectId, taskId).doc(requestId).get();
    final requesterUid = request.data()?['who'];
    if (requesterUid is! String) {
      throw StateError('The help request no longer exists.');
    }
    final batch = _firestore.batch()
      ..set(_history(projectId, taskId).doc(acceptEntryId(requestId)), {
        'who': helperUid,
        'action': HistoryAction.helpAccepted.value,
        'to': requesterUid,
        'at': FieldValue.serverTimestamp(),
      })
      ..set(
        _firestore
            .collection('notifications')
            .doc(helpAcceptedNotificationId(requestId)),
        helpAcceptedNotification(
          requesterUid: requesterUid,
          helperUid: helperUid,
          helperName: helperName,
          projectId: projectId,
          taskId: taskId,
        )..['createdAt'] = FieldValue.serverTimestamp(),
      );
    await batch.commit();
  }
}

/// The fixed history id of a help request's accept entry.
String acceptEntryId(String requestId) => 'accept_$requestId';

/// The fixed `notifications/{id}` of a help request's accept notice.
String helpAcceptedNotificationId(String requestId) =>
    'help_accepted_$requestId';

/// `notifications/{nid}` for an accepted help request (CLAUDE.md data
/// model, plus `senderId` for the rules' sender check), without
/// `createdAt`. Phase 8 adds the model and the notification center.
Map<String, dynamic> helpAcceptedNotification({
  required String requesterUid,
  required String helperUid,
  required String helperName,
  required String projectId,
  required String taskId,
}) => {
  'userId': requesterUid,
  'senderId': helperUid,
  'type': 'help_accepted',
  'projectId': projectId,
  'taskId': taskId,
  'message': '$helperName accepted your help request',
  'read': false,
};

/// The fixed `notifications/{id}` of a help request's notice to the
/// helper.
String helpRequestedNotificationId(String requestId) =>
    'help_requested_$requestId';

/// `notifications/{nid}` telling [helperUid] that [requesterName] asked
/// for their help on [taskTitle], without `createdAt`. The message is kept
/// within the rules' 200-character limit.
Map<String, dynamic> helpRequestedNotification({
  required String helperUid,
  required String requesterUid,
  required String requesterName,
  required String taskTitle,
  required String projectId,
  required String taskId,
}) => {
  'userId': helperUid,
  'senderId': requesterUid,
  'type': 'help_requested',
  'projectId': projectId,
  'taskId': taskId,
  'message':
      '${_clip(requesterName, 60)} requested your help on '
      '${_clip(taskTitle, 100)}',
  'read': false,
};

String _clip(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';
