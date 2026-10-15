import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/app_user.dart';
import '../../auth/data/user_repository.dart';
import 'project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(firestoreProvider)),
);

/// Thrown when a project can't be deleted because it still has tasks.
class ProjectHasTasksException implements Exception {
  const ProjectHasTasksException();

  @override
  String toString() =>
      'This project has tasks. Archive it instead, or delete its tasks first.';
}

/// `projects/{pid}` CRUD. Permissions are enforced by Firestore rules
/// (leader-only writes); callers check [ProjectPermissions] for the UI.
class ProjectRepository {
  ProjectRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('projects');

  /// Every project [uid] belongs to, newest first. Sorted here rather than
  /// with `orderBy`, which with `array-contains` would need a composite
  /// index.
  Stream<List<Project>> watchProjectsFor(String uid) =>
      _projects.where('memberIds', arrayContains: uid).snapshots().map((snap) {
        final projects = [
          for (final doc in snap.docs) Project.fromMap(doc.id, doc.data()),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return projects;
      });

  /// `null` once the project is deleted (or never existed).
  Stream<Project?> watchProject(String id) =>
      _projects.doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : Project.fromMap(doc.id, data);
      });

  /// Creates a project with [creatorUid] as its only member and Admin.
  /// Returns the new project's id.
  Future<String> create({
    required String creatorUid,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) async {
    final doc = _projects.doc();
    final project = Project(
      id: doc.id,
      name: name,
      description: description,
      startDate: startDate,
      deadline: deadline,
      status: ProjectStatus.active,
      createdBy: creatorUid,
      members: {creatorUid: UserRole.leader},
      createdAt: DateTime.now(),
    );
    await doc.set({
      ...project.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateDetails(
    String id, {
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
  }) => _projects.doc(id).update({
    'name': name,
    'description': description,
    'startDate': Timestamp.fromDate(startDate),
    'deadline': Timestamp.fromDate(deadline),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> setStatus(String id, ProjectStatus status) =>
      _projects.doc(id).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<bool> hasTasks(String id) async {
    final snap = await _projects.doc(id).collection('tasks').limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Deletes the project doc. Refuses while it has tasks: Firestore never
  /// deletes subcollections with their parent, so they would be orphaned.
  Future<void> delete(String id) async {
    if (await hasTasks(id)) throw const ProjectHasTasksException();
    await _projects.doc(id).delete();
  }

  Future<void> addMember(String projectId, String uid) =>
      _changeMembers(projectId, (project) => addMemberChange(project, uid));

  Future<void> removeMember(String projectId, String uid) =>
      _changeMembers(projectId, (project) => removeMemberChange(project, uid));

  /// Read-modify-write in a transaction so concurrent changes by two
  /// Admins can't drop each other's edits; `members` and `memberIds` are
  /// always written together.
  Future<void> _changeMembers(
    String projectId,
    MemberChange Function(Project project) change,
  ) => _firestore.runTransaction((tx) async {
    final ref = _projects.doc(projectId);
    final snap = await tx.get(ref);
    final data = snap.data();
    if (data == null) throw StateError('Project $projectId no longer exists');
    final next = change(Project.fromMap(snap.id, data));
    tx.update(ref, {
      'members': next.members,
      'memberIds': next.memberIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
