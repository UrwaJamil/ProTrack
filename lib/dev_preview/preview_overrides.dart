import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/auth/data/app_user.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/email_availability_repository.dart';
import '../features/auth/data/user_repository.dart';
import '../features/projects/application/projects_providers.dart';
import '../features/projects/data/project_repository.dart';
import '../features/tasks/data/task_activity_repository.dart';
import '../features/tasks/data/task_repository.dart';
import 'fakes/preview_auth_repository.dart';
import 'fakes/preview_project_repository.dart';
import 'fakes/preview_task_activity_repository.dart';
import 'fakes/preview_task_repository.dart';
import 'fakes/preview_user_repository.dart';
import 'mock/mock_activity.dart';
import 'mock/mock_people.dart';
import 'mock/mock_projects.dart';
import 'mock/mock_tasks.dart';

/// Every provider the app would back with Firebase, replaced with
/// in-memory fakes seeded from `mock/`. The raw Firebase providers throw,
/// so a screen that bypasses its repository fails loudly here instead of
/// calling Firebase.
///
/// New repositories (leave, notifications, comments, …) get a preview
/// fake and an override here in the phase that adds them.
List<Override> previewOverrides({UserRole signedInAs = UserRole.leader}) {
  final users = PreviewUserRepository(MockPeople.all);
  final tasks = PreviewTaskRepository(MockTasks.all);
  final projects = PreviewProjectRepository(MockProjects.all, tasks);
  final auth = PreviewAuthRepository(
    uidByEmail: {for (final u in MockPeople.all) u.email: u.uid},
    signedInUid: MockPeople.meFor(signedInAs),
  );

  return [
    firebaseAuthProvider.overrideWith((ref) => throw _noFirebase),
    firestoreProvider.overrideWith((ref) => throw _noFirebase),
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    emailAvailabilityRepositoryProvider.overrideWithValue(
      PreviewEmailAvailabilityRepository(users),
    ),
    projectRepositoryProvider.overrideWithValue(projects),
    taskRepositoryProvider.overrideWithValue(tasks),
    taskActivityRepositoryProvider.overrideWithValue(
      PreviewTaskActivityRepository(
        tasks,
        comments: MockActivity.comments,
        history: MockActivity.history,
        helpNotes: MockActivity.helpNotes,
      ),
    ),
    todayProvider.overrideWithValue(mockToday),
  ];
}

final _noFirebase = UnsupportedError(
  'The dev preview has no Firebase. Add a preview fake for this '
  'repository in lib/dev_preview/preview_overrides.dart.',
);
