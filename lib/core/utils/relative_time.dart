import 'date_format.dart';

/// "Just now", "10m ago", "3h ago", "Yesterday", "2d ago" (up to a week),
/// then a date — relative to [now]. No `intl`.
String formatRelativeTime(DateTime t, {required DateTime now}) {
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  // Calendar days in UTC, so a DST change can't shift them.
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  if (days == 0) return '${diff.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';
  return formatDate(t);
}
