import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/data/app_user.dart';
import 'package:team_project_manager/features/projects/application/project_filters.dart';
import 'package:team_project_manager/features/projects/data/project.dart';

import '../support/project_fixtures.dart';

void main() {
  final today = DateTime(2026, 10, 15, 14, 30);
  int noProgress(Project _) => 0;

  group('daysRemaining', () {
    test('counts whole days, ignoring the time of day', () {
      expect(daysRemaining(DateTime(2026, 10, 25), today), 10);
      expect(daysRemaining(DateTime(2026, 10, 15), today), 0);
      expect(daysRemaining(DateTime(2026, 10, 12), today), -3);
    });

    test('is not thrown off by a DST change', () {
      // Spans the late-October clock change in many time zones.
      expect(
        daysRemaining(DateTime(2026, 11, 2), DateTime(2026, 10, 20, 23)),
        13,
      );
    });
  });

  group('isOverdue', () {
    test('past deadline and unfinished', () {
      final p = testProject(deadline: DateTime(2026, 10, 14));
      expect(isOverdue(p, today: today, progress: 40), isTrue);
    });

    test('due today is not overdue yet', () {
      final p = testProject(deadline: DateTime(2026, 10, 15));
      expect(isOverdue(p, today: today, progress: 0), isFalse);
    });

    test('finished projects are never overdue', () {
      final p = testProject(deadline: DateTime(2026, 10, 1));
      expect(isOverdue(p, today: today, progress: 100), isFalse);
    });

    test('archived projects are never overdue', () {
      final p = testProject(
        deadline: DateTime(2026, 10, 1),
        status: ProjectStatus.archived,
      );
      expect(isOverdue(p, today: today, progress: 0), isFalse);
    });
  });

  group('filters', () {
    final active = testProject(id: 'a', deadline: DateTime(2026, 12, 1));
    final overdue = testProject(id: 'o', deadline: DateTime(2026, 10, 1));
    final archived = testProject(id: 'r', status: ProjectStatus.archived);
    final all = [active, overdue, archived];

    test('counts: All = Active + Overdue; Archived separate', () {
      final counts = filterCounts(all, today: today, progressOf: noProgress);
      expect(counts, {
        ProjectFilter.all: 2,
        ProjectFilter.active: 1,
        ProjectFilter.overdue: 1,
        ProjectFilter.archived: 1,
      });
    });

    test('each filter matches its bucket', () {
      bool m(Project p, ProjectFilter f) =>
          matchesFilter(p, f, today: today, progressOf: noProgress);
      expect(m(active, ProjectFilter.all), isTrue);
      expect(m(archived, ProjectFilter.all), isFalse);
      expect(m(overdue, ProjectFilter.overdue), isTrue);
      expect(m(overdue, ProjectFilter.active), isFalse);
      expect(m(archived, ProjectFilter.archived), isTrue);
    });

    test('a past-deadline project at 100% counts as Active', () {
      final counts = filterCounts(
        [overdue],
        today: today,
        progressOf: (_) => 100,
      );
      expect(counts[ProjectFilter.active], 1);
      expect(counts[ProjectFilter.overdue], 0);
    });
  });

  test('scope "mine" = projects I am in but did not create', () {
    final own = testProject(id: 'own', createdBy: 'me');
    final joined = testProject(
      id: 'joined',
      members: {'admin': UserRole.leader, 'me': UserRole.member},
    );
    final projects = [own, joined];
    expect(applyScope(projects, ProjectScope.all, 'me'), projects);
    expect(applyScope(projects, ProjectScope.mine, 'me'), [joined]);
  });
}
