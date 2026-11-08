import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_repository.dart';
import 'task.dart';
import 'task_status.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);

/// The only task fields an assignee who isn't a project Admin may change
/// (CLAUDE.md decision 3), besides `updatedAt`. Firestore rules enforce
/// the same list.
const assigneeEditableFields = {
  'status',
  'helpNote',
  'subtasks',
  'attachments',
};

/// The fields an assignee's status change writes (FR-3.6), without the
/// server timestamp.
Map<String, dynamic> assigneeStatusUpdate(TaskStatus status) => {
  'status': status.value,
};

/// [subtasks] with the one at [index] set to [done] (FR-3.5). Throws
/// [StateError] if the list changed under the user (an Admin edited the
/// subtasks meanwhile), so a stale screen can't tick the wrong portion.
List<Subtask> toggleSubtaskChange(
  List<Subtask> subtasks, {
  required int index,
  required String expectedTitle,
  required bool done,
}) {
  if (index < 0 ||
      index >= subtasks.length ||
      subtasks[index].title != expectedTitle) {
    throw StateError('The subtasks changed. Please try again.');
  }
  return [
    for (var i = 0; i < subtasks.length; i++)
      i == index ? subtasks[i].copyWith(done: done) : subtasks[i],
  ];
}

/// `projects/{pid}/tasks/{tid}` CRUD. Permissions are enforced by
/// Firestore rules; callers check `TaskPermissions` for the UI.
class TaskRepository {
  TaskRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tasks(String projectId) =>
      _firestore.collection('projects').doc(projectId).collection('tasks');

  /// Every task in a project, unsorted (providers sort for display).
  Stream<List<Task>> watchTasks(String projectId) =>
      _tasks(projectId).snapshots().map((snap) => _parseAll(snap.docs));

  /// `null` once the task is deleted (or never existed).
  Stream<Task?> watchTask(String projectId, String taskId) =>
      _tasks(projectId).doc(taskId).snapshots().map(_parse);

  /// Tasks assigned to [uid] across every project (FR-3.4). A
  /// collection-group query: needs the `tasks.assignedTo` collection-group
  /// array-contains index (see firestore.indexes.json). Sorted in the app,
  /// so no composite index is needed.
  Stream<List<Task>> watchAssignedTo(String uid) => _firestore
      .collectionGroup('tasks')
      .where('assignedTo', arrayContains: uid)
      .snapshots()
      .map((snap) => _parseAll(snap.docs));

  /// Admin only (FR-3.1). Returns the new task's id.
  Future<String> create(
    String projectId, {
    required String creatorUid,
    required TaskDraft draft,
  }) async {
    final doc = _tasks(projectId).doc();
    await doc.set({
      ...draft.toMap(),
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Admin only: replaces every editable field except status (FR-3.2,
  /// FR-3.3, FR-3.5).
  Future<void> update(String projectId, String taskId, TaskDraft draft) =>
      _tasks(projectId).doc(taskId).update({
        ...draft.toMap(includeStatus: false),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String projectId, String taskId) =>
      _tasks(projectId).doc(taskId).delete();

  /// Assignee (or Admin) status change (FR-3.6).
  Future<void> updateStatus(
    String projectId,
    String taskId,
    TaskStatus status,
  ) => _tasks(projectId).doc(taskId).update({
    ...assigneeStatusUpdate(status),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Ticks or unticks one subtask (FR-3.5). Read-modify-write in a
  /// transaction so two people ticking different portions at once don't
  /// overwrite each other.
  Future<void> setSubtaskDone(
    String projectId,
    String taskId, {
    required int index,
    required String expectedTitle,
    required bool done,
  }) => _firestore.runTransaction((tx) async {
    final ref = _tasks(projectId).doc(taskId);
    final task = _parse(await tx.get(ref));
    if (task == null) throw StateError('Task $taskId no longer exists');
    final next = toggleSubtaskChange(
      task.subtasks,
      index: index,
      expectedTitle: expectedTitle,
      done: done,
    );
    tx.update(ref, {
      'subtasks': Task.subtasksToList(next),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  static Task? _parse(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return Task.fromMap(doc.id, doc.reference.parent.parent!.id, data);
  }

  /// Skips docs with an unknown status/priority (rules prevent them)
  /// instead of failing the whole list.
  static List<Task> _parseAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => [for (final doc in docs) ?_tryParse(doc)];

  static Task? _tryParse(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return _parse(doc);
    } on FormatException {
      return null;
    }
  }
}
