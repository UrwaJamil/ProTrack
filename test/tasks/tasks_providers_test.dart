import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/projects/application/projects_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/projects/data/project_repository.dart';
import 'package:team_project_manager/features/tasks/application/tasks_providers.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/fake_projects.dart';
import '../support/fake_tasks.dart';
import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

ProviderContainer _container({
  required FakeTaskRepository tasks,
  FakeProjectRepository? projects,
  String uid = 'member1',
}) {
  final container = ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(tasks),
      projectRepositoryProvider.overrideWithValue(
        projects ?? FakeProjectRepository([testProject()]),
      ),
      currentUidProvider.overrideWithValue(uid),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('projectProgressProvider (FR-2.5, now fed by real tasks)', () {
    test('is the share of completed tasks in that project only', () async {
      final repo = FakeTaskRepository([
        testTask(id: 't1', status: TaskStatus.completed),
        testTask(id: 't2', status: TaskStatus.inProgress),
        testTask(id: 't3', status: TaskStatus.onHold),
        testTask(id: 't4', status: TaskStatus.completed),
        // Another project's task doesn't count.
        testTask(id: 'x', projectId: 'other', status: TaskStatus.todo),
      ]);
      final container = _container(tasks: repo);
      container.listen(projectProgressProvider('abcd1234'), (_, _) {});
      await container.read(projectTasksProvider('abcd1234').future);
      expect(container.read(projectProgressProvider('abcd1234')), 50);
    });

    test('updates live when a status changes', () async {
      final repo = FakeTaskRepository([
        testTask(id: 't1', status: TaskStatus.completed),
        testTask(id: 't2', status: TaskStatus.todo),
      ]);
      final container = _container(tasks: repo);
      container.listen(projectProgressProvider('abcd1234'), (_, _) {});
      await container.read(projectTasksProvider('abcd1234').future);
      expect(container.read(projectProgressProvider('abcd1234')), 50);

      await repo.updateStatus('abcd1234', 't2', TaskStatus.completed);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(projectProgressProvider('abcd1234')), 100);
    });

    test('is 0% with no tasks, and while tasks are loading', () async {
      final empty = _container(tasks: FakeTaskRepository());
      empty.listen(projectProgressProvider('abcd1234'), (_, _) {});
      await empty.read(projectTasksProvider('abcd1234').future);
      expect(empty.read(projectProgressProvider('abcd1234')), 0);

      final loading = _container(tasks: FakeTaskRepository()..neverLoad = true);
      expect(loading.read(projectProgressProvider('abcd1234')), 0);
    });
  });

  group('myTasksProvider (FR-3.4)', () {
    test('pairs assigned tasks with their project, dropping archived and '
        'foreign projects', () async {
      final projects = FakeProjectRepository([
        testProject(id: 'abcd1234'),
        testProject(
          id: 'arch0001',
          name: 'Old',
          status: ProjectStatus.archived,
        ),
      ]);
      final repo = FakeTaskRepository([
        testTask(id: 'mine', deadline: DateTime(2026, 10, 20)),
        testTask(id: 'mineSooner', deadline: DateTime(2026, 10, 17)),
        testTask(id: 'notMine', assignedTo: const ['admin']),
        testTask(id: 'archived', projectId: 'arch0001'),
        // Stale: a project this user isn't a member of.
        testTask(id: 'gone', projectId: 'zzzz9999'),
      ]);
      final container = _container(tasks: repo, projects: projects);
      container.listen(myTasksProvider, (_, _) {});
      await container.read(assignedTasksProvider.future);
      await container.read(myProjectsProvider.future);

      final result = container.read(myTasksProvider).value!;
      expect(result.map((r) => r.task.id), ['mineSooner', 'mine']);
      expect(result.first.project.name, 'Mobile App Redesign');
    });

    test('surfaces a load error', () async {
      final container = _container(
        tasks: FakeTaskRepository()..loadError = StateError('offline'),
      );
      container.listen(myTasksProvider, (_, _) {});
      await expectLater(
        container.read(assignedTasksProvider.future),
        throwsStateError,
      );
      expect(container.read(myTasksProvider).hasError, isTrue);
    });
  });
}
