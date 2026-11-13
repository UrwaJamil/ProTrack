import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/projects_providers.dart';
import 'calendar_providers.dart';

/// The Calendar's visible month and selected day. Starts on today.
typedef CalendarSelection = ({DateTime month, DateTime selected});

final calendarSelectionProvider =
    NotifierProvider<CalendarSelectionController, CalendarSelection>(
      CalendarSelectionController.new,
    );

class CalendarSelectionController extends Notifier<CalendarSelection> {
  @override
  CalendarSelection build() {
    final today = calendarDay(ref.watch(todayProvider));
    return (month: DateTime(today.year, today.month), selected: today);
  }

  /// Shows the month [delta] months away; the selection stays.
  void shiftMonth(int delta) => state = (
    month: DateTime(state.month.year, state.month.month + delta),
    selected: state.selected,
  );

  /// Selects [day]; a greyed day from a neighbouring month also shows
  /// that month.
  void select(DateTime day) {
    final d = calendarDay(day);
    state = (month: DateTime(d.year, d.month), selected: d);
  }
}
