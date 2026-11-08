import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_repository.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

void main() {
  group('assignee writes stay within the allowed fields', () {
    test('the allow-list matches CLAUDE.md decision 3', () {
      expect(assigneeEditableFields, {
        'status',
        'helpNote',
        'subtasks',
        'attachments',
      });
    });

    test('a status change writes only `status`', () {
      for (final status in TaskStatus.values) {
        final update = assigneeStatusUpdate(status);
        expect(update, {'status': status.value});
        expect(assigneeEditableFields.containsAll(update.keys), isTrue);
      }
    });
  });

  group('toggleSubtaskChange', () {
    const subtasks = [
      Subtask(title: 'Wireframes'),
      Subtask(title: 'Review', done: true),
    ];

    test('flips only the chosen subtask', () {
      expect(
        toggleSubtaskChange(
          subtasks,
          index: 0,
          expectedTitle: 'Wireframes',
          done: true,
        ),
        const [
          Subtask(title: 'Wireframes', done: true),
          Subtask(title: 'Review', done: true),
        ],
      );
      expect(
        toggleSubtaskChange(
          subtasks,
          index: 1,
          expectedTitle: 'Review',
          done: false,
        ),
        const [Subtask(title: 'Wireframes'), Subtask(title: 'Review')],
      );
    });

    test('keeps the list size and titles (what the rules allow an '
        'assignee)', () {
      final next = toggleSubtaskChange(
        subtasks,
        index: 0,
        expectedTitle: 'Wireframes',
        done: true,
      );
      expect(next.map((s) => s.title), subtasks.map((s) => s.title));
    });

    test('refuses when the list changed under the user', () {
      expect(
        () => toggleSubtaskChange(
          subtasks,
          index: 0,
          expectedTitle: 'Something else',
          done: true,
        ),
        throwsStateError,
      );
      expect(
        () => toggleSubtaskChange(
          subtasks,
          index: 5,
          expectedTitle: 'Wireframes',
          done: true,
        ),
        throwsStateError,
      );
    });
  });
}
