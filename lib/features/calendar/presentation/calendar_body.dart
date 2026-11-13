import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../../tasks/application/task_filters.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/presentation/task_paths.dart';
import '../application/calendar_providers.dart';
import '../application/calendar_selection.dart';
import 'widgets/calendar_task_tile.dart';
import 'widgets/month_calendar_card.dart';

/// The Admin's Calendar (mock 04), shown by the `CalendarScreen`
/// placeholder: a month grid with deadline dots over "Tasks on selected
/// day", for every task in the active projects the user leads.
class CalendarBody extends ConsumerWidget {
  const CalendarBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(ledProjectsProvider);
    if (projects.value?.isEmpty ?? false) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No projects you lead',
        message: 'Task deadlines from the projects you lead show up here.',
      );
    }
    return ref
        .watch(calendarTasksProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(
            message: "We couldn't load your calendar.",
            onRetry: () => ref
              ..invalidate(myProjectsProvider)
              ..invalidate(projectTasksProvider),
          ),
          data: (tasks) => _Calendar(tasks: tasks),
        );
  }
}

class _Calendar extends ConsumerWidget {
  const _Calendar({required this.tasks});

  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final selection = ref.watch(calendarSelectionProvider);
    final controller = ref.read(calendarSelectionProvider.notifier);
    final byDay = tasksByDay(tasks);
    final onDay = byDay[selection.selected] ?? const <CalendarTask>[];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            MonthCalendarCard(
              month: selection.month,
              selected: selection.selected,
              today: today,
              markers: {
                for (final e in byDay.entries)
                  e.key: dayMarker(e.value, today: today),
              },
              counts: {for (final e in byDay.entries) e.key: e.value.length},
              onPrevious: () => controller.shiftMonth(-1),
              onNext: () => controller.shiftMonth(1),
              onSelect: controller.select,
            ),
            const SizedBox(height: 20),
            Text(
              'Tasks on selected day',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (onDay.isEmpty)
              const _NoTasks()
            else
              _DayTasks(tasks: onDay, today: today),
          ],
        ),
      ),
    );
  }
}

class _DayTasks extends ConsumerWidget {
  const _DayTasks({required this.tasks, required this.today});

  final List<CalendarTask> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Names for the subtitles: project only while loading, "Unknown" if
    // the fetch fails (the list itself never waits on them).
    final profiles = ref.watch(
      userProfilesProvider(profilesKey(tasks.expand((t) => t.task.assignedTo))),
    );
    final names = profiles.hasError ? const <String, Never>{} : profiles.value;
    return Column(
      children: [
        for (final (i, t) in tasks.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          CalendarTaskTile(
            key: ValueKey('${t.project.id}/${t.task.id}'),
            item: t,
            subtitle: calendarTaskSubtitle(t, names),
            overdue: isTaskOverdue(t.task, today: today),
            onTap: () => context.push(
              taskDetailPath(t.project.id, t.task.id, adminView: true),
            ),
          ),
        ],
      ],
    );
  }
}

class _NoTasks extends StatelessWidget {
  const _NoTasks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            'No tasks due on this day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
