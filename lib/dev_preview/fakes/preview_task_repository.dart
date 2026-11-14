import '../../features/tasks/data/task.dart';
import '../../features/tasks/data/task_repository.dart';
import '../../features/tasks/data/task_status.dart';
import 'live_store.dart';

/// In-memory [TaskRepository] for the dev preview. Edits work for the
/// session and are lost on reload. Subtask toggles go through the same
/// pure [toggleSubtaskChange] the real repository uses.
class PreviewTaskRepository implements TaskRepository {
  PreviewTaskRepository(Iterable<Task> initial) {
    for (final t in initial) {
      _tasks[_key(t.projectId, t.id)] = t;
    }
  }

  /// Keyed by "projectId/taskId".
  final _tasks = <String, Task>{};
  final _store = LiveStore();
  var _nextId = 0;

  static String _key(String projectId, String taskId) => '$projectId/$taskId';

  bool hasTasks(String projectId) =>
      _tasks.values.any((t) => t.projectId == projectId);

  /// Removes [uid] from every task in [projectId] (what the real
  /// `ProjectRepository.removeMember` does in its transaction).
  void unassign(String projectId, String uid) {
    for (final entry in _tasks.entries.toList()) {
      final t = entry.value;
      if (t.projectId != projectId || !t.isAssignedTo(uid)) continue;
      _tasks[entry.key] = _rebuild(
        t,
        assignedTo: [...t.assignedTo]..remove(uid),
      );
    }
    _store.notify();
  }

  Task _rebuild(Task t, {List<String>? assignedTo}) => Task(
    id: t.id,
    projectId: t.projectId,
    title: t.title,
    description: t.description,
    assignedTo: assignedTo ?? t.assignedTo,
    priority: t.priority,
    status: t.status,
    deadline: t.deadline,
    subtasks: t.subtasks,
    createdBy: t.createdBy,
    createdAt: t.createdAt,
  );

  Task _fromDraft(
    String projectId,
    String id,
    String createdBy,
    DateTime createdAt,
    TaskDraft d,
  ) => Task(
    id: id,
    projectId: projectId,
    title: d.title,
    description: d.description,
    assignedTo: d.assignedTo,
    priority: d.priority,
    status: d.status,
    deadline: d.deadline,
    subtasks: d.subtasks,
    createdBy: createdBy,
    createdAt: createdAt,
  );

  @override
  Stream<List<Task>> watchTasks(String projectId) => _store.watch(
    () => _tasks.values.where((t) => t.projectId == projectId).toList(),
  );

  @override
  Stream<Task?> watchTask(String projectId, String taskId) =>
      _store.watch(() => _tasks[_key(projectId, taskId)]);

  @override
  Stream<List<Task>> watchAssignedTo(String uid) => _store.watch(
    () => _tasks.values.where((t) => t.isAssignedTo(uid)).toList(),
  );

  @override
  Future<String> create(
    String projectId, {
    required String creatorUid,
    required TaskDraft draft,
  }) async {
    final id = 'new${_nextId++}task';
    _tasks[_key(projectId, id)] = _fromDraft(
      projectId,
      id,
      creatorUid,
      DateTime.now(),
      draft,
    );
    _store.notify();
    return id;
  }

  @override
  Future<void> update(String projectId, String taskId, TaskDraft draft) async {
    final old = _tasks[_key(projectId, taskId)]!;
    // Like the real one, an edit never changes status.
    _tasks[_key(projectId, taskId)] = _fromDraft(
      projectId,
      taskId,
      old.createdBy,
      old.createdAt,
      draft,
    ).copyWith(status: old.status);
    _store.notify();
  }

  @override
  Future<void> delete(String projectId, String taskId) async {
    _tasks.remove(_key(projectId, taskId));
    _store.notify();
  }

  @override
  Future<void> updateStatus(
    String projectId,
    String taskId,
    TaskStatus status,
  ) async {
    final key = _key(projectId, taskId);
    _tasks[key] = _tasks[key]!.copyWith(status: status);
    _store.notify();
  }

  @override
  Future<void> setSubtaskDone(
    String projectId,
    String taskId, {
    required int index,
    required String expectedTitle,
    required bool done,
  }) async {
    final key = _key(projectId, taskId);
    final task = _tasks[key]!;
    _tasks[key] = task.copyWith(
      subtasks: toggleSubtaskChange(
        task.subtasks,
        index: index,
        expectedTitle: expectedTitle,
        done: done,
      ),
    );
    _store.notify();
  }
}
