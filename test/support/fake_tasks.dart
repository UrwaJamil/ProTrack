import 'dart:async';

import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

/// In-memory [TaskRepository]. Subtask toggles go through the same pure
/// [toggleSubtaskChange] the real one uses.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([Iterable<Task> initial = const []]) {
    for (final t in initial) {
      tasks[_key(t.projectId, t.id)] = t;
    }
  }

  /// Keyed by "projectId/taskId".
  final tasks = <String, Task>{};
  final calls = <String>[];
  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  /// Makes the watch streams error (or never emit).
  Object? loadError;
  bool neverLoad = false;

  /// Makes writes throw.
  Object? writeError;

  static String _key(String projectId, String taskId) => '$projectId/$taskId';

  void _emit() => _changes.add(null);

  /// Subscribes to changes before the first emission, so a write made
  /// right after awaiting the first value is never missed.
  Stream<T> _watch<T>(T Function() read) {
    StreamSubscription<void>? changes;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        if (neverLoad) return;
        if (loadError != null) {
          controller.addError(loadError!);
          return;
        }
        changes = _changes.stream.listen((_) => controller.add(read()));
        controller.add(read());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  void _checkWrite() {
    if (writeError != null) throw writeError!;
  }

  @override
  Stream<List<Task>> watchTasks(String projectId) => _watch(
    () => tasks.values.where((t) => t.projectId == projectId).toList(),
  );

  @override
  Stream<Task?> watchTask(String projectId, String taskId) =>
      _watch(() => tasks[_key(projectId, taskId)]);

  @override
  Stream<List<Task>> watchAssignedTo(String uid) =>
      _watch(() => tasks.values.where((t) => t.isAssignedTo(uid)).toList());

  Task _fromDraft(String projectId, String id, String createdBy, TaskDraft d) =>
      Task(
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
        createdAt: DateTime(2026, 10, 15),
      );

  @override
  Future<String> create(
    String projectId, {
    required String creatorUid,
    required TaskDraft draft,
  }) async {
    calls.add('create');
    _checkWrite();
    final id = 'task${_nextId++}';
    tasks[_key(projectId, id)] = _fromDraft(projectId, id, creatorUid, draft);
    _emit();
    return id;
  }

  @override
  Future<void> update(String projectId, String taskId, TaskDraft draft) async {
    calls.add('update:$taskId');
    _checkWrite();
    final old = tasks[_key(projectId, taskId)]!;
    // Like the real one, an edit never changes status.
    tasks[_key(projectId, taskId)] = _fromDraft(
      projectId,
      taskId,
      old.createdBy,
      draft,
    ).copyWith(status: old.status);
    _emit();
  }

  @override
  Future<void> delete(String projectId, String taskId) async {
    calls.add('delete:$taskId');
    _checkWrite();
    tasks.remove(_key(projectId, taskId));
    _emit();
  }

  @override
  Future<void> updateStatus(
    String projectId,
    String taskId,
    TaskStatus status,
  ) async {
    calls.add('updateStatus:${status.value}');
    _checkWrite();
    final key = _key(projectId, taskId);
    tasks[key] = tasks[key]!.copyWith(status: status);
    _emit();
  }

  @override
  Future<void> setSubtaskDone(
    String projectId,
    String taskId, {
    required int index,
    required String expectedTitle,
    required bool done,
  }) async {
    calls.add('setSubtaskDone:$index:$done');
    _checkWrite();
    final key = _key(projectId, taskId);
    final task = tasks[key]!;
    tasks[key] = task.copyWith(
      subtasks: toggleSubtaskChange(
        task.subtasks,
        index: index,
        expectedTitle: expectedTitle,
        done: done,
      ),
    );
    _emit();
  }
}
