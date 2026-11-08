import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/user_repository.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/project.dart';
import '../data/project_repository.dart';
import 'progress.dart';
import 'project_filters.dart';

/// The signed-in user's uid, or null while signed out.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.user?.uid)),
);

/// "Now", overridable in tests so overdue/days-left are deterministic.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Every project the signed-in user belongs to, newest first (FR-2.4).
final myProjectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchProjectsFor(uid);
});

/// One project, live; `null` once deleted or if it never existed.
final projectProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchProject(id),
);

/// FR-2.5 progress for a project, from its live task statuses. 0% while
/// the tasks are still loading (or failed to load), and for a project with
/// no tasks.
final projectProgressProvider = Provider.family<int, String>((ref, projectId) {
  final tasks = ref.watch(projectTasksProvider(projectId)).value ?? const [];
  return computeProgress(tasks.map((t) => t.status));
});

class ProjectFilterController extends Notifier<ProjectFilter> {
  @override
  ProjectFilter build() => ProjectFilter.all;

  void select(ProjectFilter filter) => state = filter;
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterController, ProjectFilter>(
      ProjectFilterController.new,
    );

class ProjectScopeController extends Notifier<ProjectScope> {
  @override
  ProjectScope build() => ProjectScope.all;

  void select(ProjectScope scope) => state = scope;
}

final projectScopeProvider =
    NotifierProvider<ProjectScopeController, ProjectScope>(
      ProjectScopeController.new,
    );

/// Stable family key for a set of uids.
String profilesKey(Iterable<String> uids) =>
    (uids.toSet().toList()..sort()).join(',');

/// Profiles (names for avatars, member rows) by uid. Key with
/// [profilesKey] so the same set of people shares one fetch.
final userProfilesProvider =
    FutureProvider.family<Map<String, AppUser>, String>((ref, key) {
      if (key.isEmpty) return Future.value(const {});
      return ref.watch(userRepositoryProvider).fetchMany(key.split(','));
    });
