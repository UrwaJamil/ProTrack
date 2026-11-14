import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/calendar/application/calendar_providers.dart';
import 'package:team_project_manager/features/calendar/presentation/widgets/month_calendar_card.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

final _project = testProject(name: 'Mobile App');

CalendarTask _ct({
  String id = 't1',
  DateTime? deadline,
  TaskStatus status = TaskStatus.todo,
  List<String> assignedTo = const ['member1'],
  String title = 'Task',
}) => (
  task: testTask(
    id: id,
    title: title,
    deadline: deadline ?? DateTime(2026, 11, 9, 17),
    status: status,
    assignedTo: assignedTo,
  ),
  project: _project,
);

AppUser _user(String uid, String name) => AppUser(
  uid: uid,
  name: name,
  email: '$uid@example.com',
  defaultRole: UserRole.member,
  skillTags: const [],
  createdAt: DateTime(2026),
);

void main() {
  group('monthGrid', () {
    test('Nov 2026: Monday first, 42 days, from Oct 26', () {
      final g = monthGrid(DateTime(2026, 11));
      expect(g.length, 42);
      expect(g.first, DateTime(2026, 10, 26));
      expect(g.first.weekday, DateTime.monday);
      expect(g[6], DateTime(2026, 11, 1)); // Sunday
      expect(g.last, DateTime(2026, 12, 6));
    });

    test('a month starting on Monday starts on its 1st', () {
      // June 1 2026 is a Monday.
      expect(monthGrid(DateTime(2026, 6)).first, DateTime(2026, 6, 1));
    });

    test('Feb 2027 and the year boundary', () {
      final feb = monthGrid(DateTime(2027, 2));
      expect(feb.first, DateTime(2027, 2, 1)); // a Monday
      expect(feb.where((d) => d.month == 2).length, 28);
      final jan = monthGrid(DateTime(2027, 1));
      expect(jan.first, DateTime(2026, 12, 28));
    });

    test('every cell is midnight, even across DST changes', () {
      for (final m in [DateTime(2026, 3), DateTime(2026, 10)]) {
        for (final d in monthGrid(m)) {
          expect((d.hour, d.minute), (0, 0));
        }
      }
    });
  });

  test('monthTitle', () {
    expect(monthTitle(DateTime(2026, 11)), 'November 2026');
  });

  group('days and markers', () {
    final today = DateTime(2026, 11, 9, 10);

    test('tasks are grouped by deadline day, open first', () {
      final byDay = tasksByDay([
        _ct(id: 'a', status: TaskStatus.completed, title: 'A'),
        _ct(id: 'b', title: 'B'),
        _ct(id: 'c', deadline: DateTime(2026, 11, 12)),
      ]);
      expect(byDay.keys.toSet(), {
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 12),
      });
      expect(byDay[DateTime(2026, 11, 9)]!.map((t) => t.task.id), ['b', 'a']);
    });

    test('red when any task that day is overdue', () {
      final past = DateTime(2026, 11, 6);
      expect(dayMarker(null, today: today), DayMarker.none);
      expect(dayMarker([_ct()], today: today), DayMarker.due);
      expect(dayMarker([_ct(deadline: past)], today: today), DayMarker.overdue);
      expect(
        dayMarker([
          _ct(deadline: past, status: TaskStatus.completed),
          _ct(id: 'x', deadline: past),
        ], today: today),
        DayMarker.overdue,
      );
      // Completed past its deadline: a normal dot, not overdue.
      expect(
        dayMarker([
          _ct(deadline: past, status: TaskStatus.completed),
        ], today: today),
        DayMarker.due,
      );
    });
  });

  group('subtitle', () {
    final names = {
      'member1': _user('member1', 'Ayesha Noor'),
      'member2': _user('member2', 'Hamza Farooq'),
    };

    test('project • assignee, +N, Unassigned, Unknown', () {
      expect(calendarTaskSubtitle(_ct(), names), 'Mobile App • Ayesha Noor');
      expect(
        calendarTaskSubtitle(_ct(assignedTo: ['member2', 'member1']), names),
        'Mobile App • Hamza Farooq +1',
      );
      expect(
        calendarTaskSubtitle(_ct(assignedTo: const []), names),
        'Mobile App • Unassigned',
      );
      expect(
        calendarTaskSubtitle(_ct(assignedTo: ['gone']), names),
        'Mobile App • Unknown',
      );
    });

    test('project only while names load', () {
      expect(calendarTaskSubtitle(_ct(), null), 'Mobile App');
      expect(
        calendarTaskSubtitle(_ct(assignedTo: const []), null),
        'Mobile App • Unassigned',
      );
    });
  });
}
