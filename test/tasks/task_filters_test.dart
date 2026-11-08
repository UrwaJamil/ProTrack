import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/tasks/application/task_filters.dart';
import 'package:team_project_manager/features/tasks/data/task_priority.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/task_fixtures.dart';

void main() {
  final today = DateTime(2026, 10, 15, 14, 30);

  group('isTaskOverdue', () {
    test('deadline day passed and not completed', () {
      expect(
        isTaskOverdue(testTask(deadline: DateTime(2026, 10, 14)), today: today),
        isTrue,
      );
    });

    test('due today is not overdue yet', () {
      expect(
        isTaskOverdue(testTask(deadline: DateTime(2026, 10, 15)), today: today),
        isFalse,
      );
    });

    test('a completed task is never overdue', () {
      expect(
        isTaskOverdue(
          testTask(
            deadline: DateTime(2026, 10, 1),
            status: TaskStatus.completed,
          ),
          today: today,
        ),
        isFalse,
      );
    });

    test('On Hold past its deadline is still overdue', () {
      expect(
        isTaskOverdue(
          testTask(deadline: DateTime(2026, 10, 1), status: TaskStatus.onHold),
          today: today,
        ),
        isTrue,
      );
    });
  });

  test('sortTasks: open first by deadline, then priority, then title; '
      'completed last', () {
    final sorted = sortTasks([
      testTask(
        id: 'done',
        deadline: DateTime(2026, 10, 1),
        status: TaskStatus.completed,
      ),
      testTask(id: 'late', deadline: DateTime(2026, 10, 20)),
      testTask(
        id: 'lowSoon',
        deadline: DateTime(2026, 10, 16),
        priority: TaskPriority.low,
      ),
      testTask(
        id: 'highSoon',
        deadline: DateTime(2026, 10, 16),
        priority: TaskPriority.high,
      ),
      testTask(id: 'overdue', deadline: DateTime(2026, 10, 10)),
    ]);
    expect(sorted.map((t) => t.id), [
      'overdue',
      'highSoon',
      'lowSoon',
      'late',
      'done',
    ]);
  });
}
