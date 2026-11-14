import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/calendar/application/calendar_providers.dart';
import 'package:team_project_manager/features/projects/data/project.dart';
import 'package:team_project_manager/features/reports/application/analytics_providers.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

import '../support/project_fixtures.dart';
import '../support/task_fixtures.dart';

final _today = DateTime(2026, 11, 9, 10);
final _a = testProject(id: 'a', name: 'A');
final _b = testProject(id: 'b', name: 'B');

CalendarTask _t(
  Project p,
  String id,
  TaskStatus status, {
  DateTime? deadline,
}) => (
  task: testTask(
    id: id,
    projectId: p.id,
    status: status,
    deadline: deadline ?? DateTime(2026, 11, 20),
  ),
  project: p,
);

void main() {
  test('counts, completed %, overdue, blocked and per-project progress', () {
    final a = computeAnalytics(
      [_a, _b],
      [
        _t(_a, '1', TaskStatus.completed),
        _t(_a, '2', TaskStatus.completed, deadline: DateTime(2026, 11, 1)),
        _t(_a, '3', TaskStatus.inProgress, deadline: DateTime(2026, 11, 1)),
        _t(_b, '4', TaskStatus.blocked),
        _t(_b, '5', TaskStatus.blocked, deadline: DateTime(2026, 11, 8)),
        _t(_b, '6', TaskStatus.todo),
        _t(_b, '7', TaskStatus.onHold),
      ],
      today: _today,
    );
    expect(a.projectCount, 2);
    expect(a.totalTasks, 7);
    expect(a.countsByStatus, {
      TaskStatus.todo: 1,
      TaskStatus.inProgress: 1,
      TaskStatus.onHold: 1,
      TaskStatus.blocked: 2,
      TaskStatus.completed: 2,
    });
    // 2 / 7 = 28.6% → 28 (rounded down, like FR-2.5).
    expect(a.completedPercent, 28);
    // A completed task past its deadline isn't overdue.
    expect(a.overdue, 2);
    expect(a.blocked, 2);
    expect(a.projectProgress.map((p) => (p.project.id, p.percent)), [
      ('a', 66),
      ('b', 0),
    ]);
  });

  test('no tasks: zeros, and projects keep their order at 0%', () {
    final a = computeAnalytics([_b, _a], const [], today: _today);
    expect(a.projectCount, 2);
    expect(a.totalTasks, 0);
    expect(a.completedPercent, 0);
    expect(a.overdue, 0);
    expect(a.countsByStatus.values, everyElement(0));
    expect(a.countsByStatus.keys.toSet(), TaskStatus.values.toSet());
    expect(a.projectProgress.map((p) => p.project.id), ['b', 'a']);
    expect(a.projectProgress.map((p) => p.percent), [0, 0]);
  });

  test('all completed is 100%', () {
    final a = computeAnalytics(
      [_a],
      [_t(_a, '1', TaskStatus.completed), _t(_a, '2', TaskStatus.completed)],
      today: _today,
    );
    expect(a.completedPercent, 100);
    expect(a.projectProgress.single.percent, 100);
  });
}
