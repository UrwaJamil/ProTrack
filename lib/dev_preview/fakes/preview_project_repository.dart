import '../../features/auth/data/app_user.dart';
import '../../features/projects/data/project.dart';
import '../../features/projects/data/project_repository.dart';
import 'live_store.dart';
import 'preview_task_repository.dart';

/// In-memory [ProjectRepository] for the dev preview. Member changes go
/// through the same pure [addMemberChange] / [removeMemberChange] the real
/// repository uses.
class PreviewProjectRepository implements ProjectRepository {
  PreviewProjectRepository(Iterable<Project> initial, this._tasks) {
    for (final p in initial) {
      _projects[p.id] = p;
    }
  }

  final PreviewTaskRepository _tasks;
  final _projects = <String, Project>{};
  final _store = LiveStore();
  var _nextId = 0;

  List<Project> _forUser(String uid) =>
      _projects.values.where((p) => p.members.containsKey(uid)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Project _copy(
    Project p, {
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? deadline,
    ProjectStatus? status,
    Map<String, UserRole>? members,
  }) => Project(
    id: p.id,
    name: name ?? p.name,
    description: description ?? p.description,
    startDate: startDate ?? p.startDate,
    deadline: deadline ?? p.deadline,
    status: status ?? p.status,
    createdBy: p.createdBy,
    members: members ?? p.members,
    createdAt: p.createdAt,
  );

  @override
  Stream<List<Project>> watchProjectsFor(String uid) =>
      _store.watch(() => _forUser(uid));

  @override
  Stream<Project?> watchProject(String id) => _store.watch(() => _projects[id]);

  @override
  Future<String> create({
    required String creatorUid,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) async {
    final id = 'new${_nextId++}proj';
    _projects[id] = Project(
      id: id,
      name: name,
      description: description,
      startDate: startDate,
      deadline: deadline,
      status: ProjectStatus.active,
      createdBy: creatorUid,
      members: {creatorUid: UserRole.leader},
      createdAt: DateTime.now(),
    );
    _store.notify();
    return id;
  }

  @override
  Future<void> updateDetails(
    String id, {
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) async {
    _projects[id] = _copy(
      _projects[id]!,
      name: name,
      description: description,
      startDate: startDate,
      deadline: deadline,
    );
    _store.notify();
  }

  @override
  Future<void> setStatus(String id, ProjectStatus status) async {
    _projects[id] = _copy(_projects[id]!, status: status);
    _store.notify();
  }

  @override
  Future<bool> hasTasks(String id) async => _tasks.hasTasks(id);

  @override
  Future<void> delete(String id) async {
    if (_tasks.hasTasks(id)) throw const ProjectHasTasksException();
    _projects.remove(id);
    _store.notify();
  }

  @override
  Future<void> addMember(String projectId, String uid) async =>
      _apply(projectId, addMemberChange(_projects[projectId]!, uid));

  @override
  Future<void> removeMember(String projectId, String uid) async {
    _apply(projectId, removeMemberChange(_projects[projectId]!, uid));
    _tasks.unassign(projectId, uid);
  }

  void _apply(String projectId, MemberChange change) {
    _projects[projectId] = _copy(
      _projects[projectId]!,
      members: {
        for (final e in change.members.entries)
          e.key: UserRole.fromValue(e.value),
      },
    );
    _store.notify();
  }
}
