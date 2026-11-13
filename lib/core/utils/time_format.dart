import 'date_format.dart';

/// "10:15 AM". Hand-rolled like `formatDate` (no `intl`).
String formatTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute '
      '${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today, 02:15 PM", "Yesterday, 04:30 PM", else "Oct 12, 2026, 10:00 AM"
/// — relative to [now].
String formatDayTime(DateTime t, {required DateTime now}) {
  // UTC dates, so a DST change can't make a day 23 hours long.
  final day = DateTime.utc(t.year, t.month, t.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  final label = switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => formatDate(t),
  };
  return '$label, ${formatTime(t)}';
}
