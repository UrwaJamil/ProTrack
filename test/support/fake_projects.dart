import 'dart:async';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';

/// In-memory [ProjectRepository]. Member changes go through the same pure
/// [addMemberChange] / [removeMemberChange] the real one uses.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository([Iterable<Project> initial = const []]) {
    for (final p in initial) {
      projects[p.id] = p;
    }
  }

  final projects = <String, Project>{};
  final calls = <String>[];
  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  /// Makes [watchProjectsFor] never emit (loading) or emit an error.
  bool neverLoad = false;
  Object? loadError;

  /// Ids of projects that have tasks (delete is refused for them).
  final withTasks = <String>{};

  void _emit() => _changes.add(null);

  List<Project> _forUser(String uid) =>
      projects.values.where((p) => p.members.containsKey(uid)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Project>> watchProjectsFor(String uid) async* {
    if (neverLoad) {
      await Completer<void>().future;
    }
    if (loadError != null) throw loadError!;
    yield _forUser(uid);
    await for (final _ in _changes.stream) {
      yield _forUser(uid);
    }
  }

  @override
  Stream<Project?> watchProject(String id) async* {
    yield projects[id];
    await for (final _ in _changes.stream) {
      yield projects[id];
    }
  }

  @override
  Future<String> create({
    required String creatorUid,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) async {
    calls.add('create');
    final id = 'proj${_nextId++}abcd';
    projects[id] = Project(
      id: id,
      name: name,
      description: description,
      startDate: startDate,
      deadline: deadline,
      status: ProjectStatus.active,
      createdBy: creatorUid,
      members: {creatorUid: UserRole.leader},
      createdAt: DateTime(2026, 10, 15),
    );
    _emit();
    return id;
  }

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
  Future<void> updateDetails(
    String id, {
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) async {
    calls.add('updateDetails');
    projects[id] = _copy(
      projects[id]!,
      name: name,
      description: description,
      startDate: startDate,
      deadline: deadline,
    );
    _emit();
  }

  @override
  Future<void> setStatus(String id, ProjectStatus status) async {
    calls.add('setStatus:${status.value}');
    projects[id] = _copy(projects[id]!, status: status);
    _emit();
  }

  @override
  Future<bool> hasTasks(String id) async => withTasks.contains(id);

  @override
  Future<void> delete(String id) async {
    calls.add('delete');
    if (withTasks.contains(id)) throw const ProjectHasTasksException();
    projects.remove(id);
    _emit();
  }

  @override
  Future<void> addMember(String projectId, String uid) async {
    calls.add('addMember:$uid');
    _apply(projectId, addMemberChange(projects[projectId]!, uid));
  }

  @override
  Future<void> removeMember(String projectId, String uid) async {
    calls.add('removeMember:$uid');
    _apply(projectId, removeMemberChange(projects[projectId]!, uid));
  }

  void _apply(String projectId, MemberChange change) {
    projects[projectId] = _copy(
      projects[projectId]!,
      members: {
        for (final e in change.members.entries)
          e.key: UserRole.fromValue(e.value),
      },
    );
    _emit();
  }
}
