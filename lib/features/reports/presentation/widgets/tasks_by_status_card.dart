import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../tasks/data/task_status.dart';

/// Legend and donut order (mock 03), Not Started last.
const analyticsStatusOrder = [
  TaskStatus.completed,
  TaskStatus.inProgress,
  TaskStatus.onHold,
  TaskStatus.blocked,
  TaskStatus.todo,
];

/// Segment color per status, from the task-badge tokens: Completed green,
/// In Progress blue, On Hold navy, Blocked amber, Not Started grey.
Color analyticsStatusColor(AppColors c, TaskStatus s) => switch (s) {
  TaskStatus.completed => c.statusCompletedText,
  TaskStatus.inProgress => c.statusInProgressText,
  TaskStatus.onHold => c.statusOnHoldText,
  TaskStatus.blocked => c.statusBlockedText,
  TaskStatus.todo => c.statusToDoText,
};

/// "Tasks by status" (mock 03): an fl_chart donut with the total in the
/// center and a 2-column legend with counts.
class TasksByStatusCard extends StatelessWidget {
  const TasksByStatusCard({super.key, required this.counts});

  final Map<TaskStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    final total = counts.values.fold(0, (a, b) => a + b);
    final summary = [
      for (final s in analyticsStatusOrder) '${counts[s] ?? 0} ${s.label}',
    ].join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasks by status',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: '$total ${total == 1 ? 'task' : 'tasks'}: $summary',
              excludeSemantics: true,
              child: SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: total > 0 ? 2 : 0,
                        centerSpaceRadius: 58,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: _sections(colors, total, theme),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Total Tasks',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Legend(counts: counts, colors: colors),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _sections(
    AppColors colors,
    int total,
    ThemeData theme,
  ) {
    // No tasks: one empty grey ring.
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: theme.colorScheme.surfaceContainerHighest,
          radius: 18,
          showTitle: false,
        ),
      ];
    }
    return [
      for (final s in analyticsStatusOrder)
        if ((counts[s] ?? 0) > 0)
          PieChartSectionData(
            value: counts[s]!.toDouble(),
            color: analyticsStatusColor(colors, s),
            radius: 18,
            showTitle: false,
          ),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.counts, required this.colors});

  final Map<TaskStatus, int> counts;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final s in analyticsStatusOrder)
        _LegendItem(
          label: s.label,
          count: counts[s] ?? 0,
          color: analyticsStatusColor(colors, s),
        ),
    ];
    return ExcludeSemantics(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: Row(
                children: [
                  Expanded(child: items[i]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: i + 1 < items.length
                        ? items[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
