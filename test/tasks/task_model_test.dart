import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_priority.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/task_fixtures.dart';

void main() {
  group('TaskStatus', () {
    test('stored values and display labels (FR-3.6 wording)', () {
      expect(
        {for (final s in TaskStatus.values) s.value: s.label},
        {
          'todo': 'Not Started',
          'in_progress': 'In Progress',
          'on_hold': 'On Hold',
          'blocked': 'Blocked',
          'completed': 'Completed',
        },
      );
    });

    test('the four FR-3.6 statuses are choosable; Blocked waits for '
        'Phase 4', () {
      expect(TaskStatus.choosable, [
        TaskStatus.todo,
        TaskStatus.inProgress,
        TaskStatus.onHold,
        TaskStatus.completed,
      ]);
    });

    test('fromValue is strict', () {
      expect(TaskStatus.fromValue('on_hold'), TaskStatus.onHold);
      expect(() => TaskStatus.fromValue('On Hold'), throwsFormatException);
      expect(() => TaskStatus.fromValue('not_started'), throwsFormatException);
      expect(() => TaskStatus.fromValue(null), throwsFormatException);
    });
  });

  group('TaskPriority', () {
    test('fromValue is strict', () {
      expect(TaskPriority.fromValue('high'), TaskPriority.high);
      expect(() => TaskPriority.fromValue('urgent'), throwsFormatException);
    });
  });

  group('Task', () {
    test('draft.toMap / fromMap round-trip', () {
      final task = testTask(
        subtasks: const [
          Subtask(title: 'Wireframes', done: true),
          Subtask(title: 'Review'),
        ],
      );
      final map = task.draft.toMap();
      expect(map, {
        'title': task.title,
        'description': task.description,
        'assignedTo': ['member1'],
        'priority': 'medium',
        'status': 'todo',
        'deadline': Timestamp.fromDate(task.deadline),
        'subtasks': [
          {'title': 'Wireframes', 'done': true},
          {'title': 'Review', 'done': false},
        ],
      });

      final back = Task.fromMap('tid12345', 'abcd1234', {
        ...map,
        'createdBy': 'admin',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
      });
      expect(back.projectId, 'abcd1234');
      expect(back.title, task.title);
      expect(back.assignedTo, ['member1']);
      expect(back.priority, TaskPriority.medium);
      expect(back.status, TaskStatus.todo);
      expect(back.deadline, task.deadline);
      expect(back.subtasks, task.subtasks);
      expect(back.subtasksDone, 1);
      expect(back.createdBy, 'admin');
      expect(back.shortId, 'TSK-TID1');
    });

    test('rejects an unknown status rather than guessing', () {
      expect(
        () => Task.fromMap('t', 'p', {'status': 'done', 'priority': 'low'}),
        throwsFormatException,
      );
    });

    test('ignores malformed assignee and subtask entries', () {
      final task = Task.fromMap('t', 'p', {
        'status': 'todo',
        'priority': 'low',
        'assignedTo': ['a', 3, null],
        'subtasks': [
          {'title': 'ok'},
          'junk',
        ],
      });
      expect(task.assignedTo, ['a']);
      expect(task.subtasks, const [Subtask(title: 'ok')]);
    });
  });
}
