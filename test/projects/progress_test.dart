import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/projects/application/progress.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

void main() {
  const done = TaskStatus.completed;

  test('no tasks is 0%', () {
    expect(computeProgress(const []), 0);
  });

  test('share of completed tasks, as a whole percentage', () {
    expect(computeProgress([done, TaskStatus.todo]), 50);
    expect(computeProgress([done, done, done, TaskStatus.inProgress]), 75);
  });

  test('every status but completed counts as not done', () {
    expect(
      computeProgress([
        TaskStatus.todo,
        TaskStatus.inProgress,
        TaskStatus.onHold,
        TaskStatus.blocked,
      ]),
      0,
    );
    expect(
      computeProgress([done, TaskStatus.onHold, TaskStatus.blocked, done]),
      50,
    );
  });

  test('rounds down, so only all-done reaches 100', () {
    expect(computeProgress([done, done, TaskStatus.todo]), 66);
    expect(computeProgress([done, done, done]), 100);
  });

  test('TaskStatus values match the stored strings', () {
    expect(TaskStatus.inProgress.value, 'in_progress');
    expect(TaskStatus.fromValue('blocked'), TaskStatus.blocked);
    expect(() => TaskStatus.fromValue('done'), throwsFormatException);
  });
}
