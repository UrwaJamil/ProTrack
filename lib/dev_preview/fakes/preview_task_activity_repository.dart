import '../../features/tasks/data/help_note.dart';
import '../../features/tasks/data/task_activity_repository.dart';
import '../../features/tasks/data/task_comment.dart';
import '../../features/tasks/data/task_history_entry.dart';
import '../../features/tasks/data/task_repository.dart';
import '../../features/tasks/data/task_status.dart';
import 'live_store.dart';

/// In-memory [TaskActivityRepository] for the dev preview. A help
/// request also sets the task's status through [tasks], like the real
/// batch does.
class PreviewTaskActivityRepository implements TaskActivityRepository {
  PreviewTaskActivityRepository(
    this.tasks, {
    Map<String, List<TaskComment>> comments = const {},
    Map<String, List<TaskHistoryEntry>> history = const {},
    Map<String, HelpNote> helpNotes = const {},
  }) {
    comments.forEach((k, v) => _comments[k] = [...v]);
    history.forEach((k, v) => _history[k] = [...v]);
    _helpNotes.addAll(helpNotes);
  }

  final TaskRepository tasks;

  /// All keyed by "projectId/taskId".
  final _comments = <String, List<TaskComment>>{};
  final _history = <String, List<TaskHistoryEntry>>{};
  final _helpNotes = <String, HelpNote>{};
  final _store = LiveStore();
  var _nextId = 0;

  static String key(String projectId, String taskId) => '$projectId/$taskId';

  String _id() => 'preview-${_nextId++}';

  @override
  Stream<List<TaskComment>> watchComments(String projectId, String taskId) =>
      _store.watch(
        () =>
            [...?_comments[key(projectId, taskId)]]
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Future<void> addComment(
    String projectId,
    String taskId, {
    required String authorId,
    required String text,
  }) async {
    _comments
        .putIfAbsent(key(projectId, taskId), () => [])
        .add(
          TaskComment(
            id: _id(),
            authorId: authorId,
            text: text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    _store.notify();
  }

  @override
  Future<void> editComment(
    String projectId,
    String taskId,
    String commentId,
    String text,
  ) async {
    final list = _comments[key(projectId, taskId)] ?? [];
    final i = list.indexWhere((c) => c.id == commentId);
    if (i < 0) return;
    final c = list[i];
    list[i] = TaskComment(
      id: c.id,
      authorId: c.authorId,
      text: text.trim(),
      createdAt: c.createdAt,
      editedAt: DateTime.now(),
    );
    _store.notify();
  }

  @override
  Future<void> deleteComment(
    String projectId,
    String taskId,
    String commentId,
  ) async {
    _comments[key(projectId, taskId)]?.removeWhere((c) => c.id == commentId);
    _store.notify();
  }

  @override
  Stream<List<TaskHistoryEntry>> watchHistory(
    String projectId,
    String taskId, {
    required int limit,
  }) => _store.watch(
    () => ([
      ...?_history[key(projectId, taskId)],
    ]..sort((a, b) => b.at.compareTo(a.at))).take(limit).toList(),
  );

  @override
  Stream<HelpNote?> watchHelpNote(String projectId, String taskId) =>
      _store.watch(() => _helpNotes[key(projectId, taskId)]);

  @override
  Future<void> requestHelp(
    String projectId,
    String taskId, {
    required String requesterUid,
    required TaskStatus previousStatus,
    required HelpNote note,
  }) async {
    await tasks.updateStatus(projectId, taskId, TaskStatus.blocked);
    final id = _id();
    _helpNotes[key(projectId, taskId)] = note.withRequestId(id);
    _history
        .putIfAbsent(key(projectId, taskId), () => [])
        .add(
          TaskHistoryEntry(
            id: id,
            who: requesterUid,
            action: HistoryAction.helpRequested,
            from: previousStatus.value,
            to: note.taggedUserId,
            at: DateTime.now(),
          ),
        );
    _store.notify();
  }

  /// Notifications written by [acceptHelp], keyed by id (shown by the
  /// Phase 8 notification center).
  final notifications = <String, Map<String, dynamic>>{};

  @override
  Stream<bool> watchAccepted(
    String projectId,
    String taskId,
    String requestId,
  ) => _store.watch(
    () => (_history[key(projectId, taskId)] ?? const <TaskHistoryEntry>[]).any(
      (e) => e.id == acceptEntryId(requestId),
    ),
  );

  @override
  Future<void> acceptHelp(
    String projectId,
    String taskId, {
    required String helperUid,
    required String helperName,
    required HelpNote note,
  }) async {
    final requestId = note.requestId;
    if (requestId == null) throw StateError('No help request to accept');
    final list = _history.putIfAbsent(key(projectId, taskId), () => []);
    final request = list.where((e) => e.id == requestId).firstOrNull;
    if (request == null) throw StateError('The help request is gone');
    final id = acceptEntryId(requestId);
    // Like the rules: a second accept of the same request is refused.
    if (list.any((e) => e.id == id)) throw StateError('Already accepted');
    list.add(
      TaskHistoryEntry(
        id: id,
        who: helperUid,
        action: HistoryAction.helpAccepted,
        to: request.who,
        at: DateTime.now(),
      ),
    );
    notifications[helpAcceptedNotificationId(
      requestId,
    )] = helpAcceptedNotification(
      requesterUid: request.who,
      helperUid: helperUid,
      helperName: helperName,
      projectId: projectId,
      taskId: taskId,
    )..['createdAt'] = DateTime.now();
    _store.notify();
  }
}
