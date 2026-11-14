import 'package:flutter/material.dart';

import '../../application/calendar_providers.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// "November 2026".
String monthTitle(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// The month card (mock 04): month name with ‹ ›, an M–S header and a
/// Monday-first 6-week grid. Neighbouring-month days are greyed, today has
/// a ring, the selected day is a filled primary circle, and a dot marks
/// days with tasks due (error-colored if one is overdue).
class MonthCalendarCard extends StatelessWidget {
  const MonthCalendarCard({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.markers,
    required this.counts,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Dot per day (midnight keys); missing = none.
  final Map<DateTime, DayMarker> markers;

  /// Tasks due per day, for the screen-reader label.
  final Map<DateTime, int> counts;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final days = monthGrid(month);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      monthTitle(month),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevious,
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final d in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (var week = 0; week < 6; week++)
              Row(
                children: [
                  for (final day in days.skip(week * 7).take(7))
                    Expanded(
                      child: _DayCell(
                        day: day,
                        inMonth: day.month == month.month,
                        isToday: day == calendarDay(today),
                        isSelected: day == selected,
                        marker: markers[day] ?? DayMarker.none,
                        count: counts[day] ?? 0,
                        onTap: () => onSelect(day),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.marker,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final DayMarker marker;
  final int count;
  final VoidCallback onTap;

  String get _label {
    final parts = [
      '${_weekdayNames[day.weekday - 1]}, '
          '${_shortMonths[day.month - 1]} ${day.day}',
      if (isToday) 'today',
      if (count > 0) '$count ${count == 1 ? 'task' : 'tasks'} due',
      if (marker == DayMarker.overdue) 'overdue',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textColor = isSelected
        ? colors.onPrimary
        : inMonth
        ? colors.onSurface
        : colors.onSurfaceVariant.withValues(alpha: 0.55);
    final dotColor = switch (marker) {
      DayMarker.none => null,
      DayMarker.due =>
        inMonth ? colors.secondary : colors.secondary.withValues(alpha: 0.5),
      DayMarker.overdue => colors.error,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: _label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primary : null,
                  border: isToday && !isSelected
                      ? Border.all(color: colors.secondary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                key: dotColor == null
                    ? null
                    : ValueKey('dot-${marker.name}-${day.toIso8601String()}'),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
