const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Nov 28, 2026". Hand-rolled to avoid pulling in `intl` for one format.
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Oct 1 – Nov 28, 2026", or with both years when they differ.
String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${_months[start.month - 1]} ${start.day} – ${formatDate(end)}';
  }
  return '${formatDate(start)} – ${formatDate(end)}';
}
