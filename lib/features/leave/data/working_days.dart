/// The calendar day of [d] (time dropped).
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from [from] to [to], both included (0 if [to] is
/// before [from]).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = dayOf(from);
  final b = dayOf(to);
  if (b.isBefore(a)) return 0;
  // Count by stepping days rather than dividing durations, so DST
  // changes can't shift the result.
  var n = 0;
  for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
    n++;
  }
  return n;
}

/// Working days from [from] to [to], both included: Monday–Friday that
/// aren't in [holidays]. A [halfDay] counts as 0.5 and only applies to a
/// single working day; it's ignored for longer ranges.
double workingDaysBetween(
  DateTime from,
  DateTime to, {
  Set<DateTime> holidays = const {},
  bool halfDay = false,
}) {
  final a = dayOf(from);
  final b = dayOf(to);
  if (b.isBefore(a)) return 0;
  final off = {for (final h in holidays) dayOf(h)};
  var n = 0;
  for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) {
    final weekend =
        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    if (!weekend && !off.contains(d)) n++;
  }
  if (halfDay && n == 1 && a == b) return 0.5;
  return n.toDouble();
}

/// "3", "0.5", "8.5": whole numbers without the ".0".
String formatDays(num days) =>
    days == days.roundToDouble() ? '${days.round()}' : days.toString();

/// "3 working days", "1 working day", "0.5 working day".
String workingDaysLabel(num days) =>
    '${formatDays(days)} working ${days == 1 || days == 0.5 ? 'day' : 'days'}';
