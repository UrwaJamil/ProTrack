import 'leave_type.dart';
import 'working_days.dart';

/// `settings/leave`: yearly allowances per type and the holiday list.
/// Read-only in the app; edited in the Firebase console (docs/PLAN.md).
///
/// ```
/// allowances: {casual: 10, sick: 8, emergency: 3}
/// holidays:   ["2026-12-25", ...]   // YYYY-MM-DD strings
/// ```
class LeaveSettings {
  const LeaveSettings({required this.allowances, this.holidays = const {}});

  /// Used until the console doc exists (the agreed seed values).
  static const defaults = LeaveSettings(
    allowances: {
      LeaveType.casual: 10,
      LeaveType.sick: 8,
      LeaveType.emergency: 3,
    },
  );

  final Map<LeaveType, num> allowances;
  final Set<DateTime> holidays;

  num allowanceFor(LeaveType type) => allowances[type] ?? 0;

  /// A missing doc gives [defaults]; a missing or malformed field falls
  /// back to its default rather than failing the screen.
  factory LeaveSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    final raw = map['allowances'];
    final allowances = <LeaveType, num>{...defaults.allowances};
    if (raw is Map) {
      for (final type in LeaveType.values.where((t) => t.hasBalance)) {
        final v = raw[type.value];
        if (v is num && v >= 0) allowances[type] = v;
      }
    }
    final holidays = <DateTime>{};
    final rawHolidays = map['holidays'];
    if (rawHolidays is List) {
      for (final h in rawHolidays) {
        final parsed = h is String ? DateTime.tryParse(h) : null;
        if (parsed != null) holidays.add(dayOf(parsed));
      }
    }
    return LeaveSettings(allowances: allowances, holidays: holidays);
  }
}
