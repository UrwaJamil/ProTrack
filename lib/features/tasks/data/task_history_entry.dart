import 'package:cloud_firestore/cloud_firestore.dart';

/// What a history entry records. Stored as [value]; the rules accept
/// exactly these strings.
///
/// Phase 4 only writes [helpRequested] and [helpAccepted] (actions from
/// the new screens).
/// The rest are reserved for when the existing flows (status selector,
/// task edit, reassign, subtasks) get history, through additive hooks or
/// a Cloud Function — see docs/PLAN.md.
enum HistoryAction {
  created('created'),
  statusChanged('status_changed'),
  edited('edited'),
  reassigned('reassigned'),
  subtaskCompleted('subtask_completed'),
  helpRequested('help_requested'),

  /// Written only by the helper named in the help note, once per request.
  helpAccepted('help_accepted');

  const HistoryAction(this.value);

  final String value;

  static HistoryAction fromValue(String? value) =>
      HistoryAction.values.firstWhere(
        (a) => a.value == value,
        orElse: () => throw FormatException('Unknown history action: $value'),
      );
}

/// `projects/{pid}/tasks/{tid}/history/{hid}`: who did what, when.
/// Create-only (rules forbid update and delete).
class TaskHistoryEntry {
  const TaskHistoryEntry({
    required this.id,
    required this.who,
    required this.action,
    required this.at,
    this.from,
    this.to,
  });

  final String id;

  /// The uid who acted.
  final String who;
  final HistoryAction action;

  /// Stored values (e.g. task status values), not display text.
  final String? from;
  final String? to;
  final DateTime at;

  /// Throws [FormatException] for an unknown action.
  factory TaskHistoryEntry.fromMap(String id, Map<String, dynamic> map) =>
      TaskHistoryEntry(
        id: id,
        who: map['who'] as String? ?? '',
        action: HistoryAction.fromValue(map['action'] as String?),
        from: map['from'] as String?,
        to: map['to'] as String?,
        at: (map['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'who': who,
    'action': action.value,
    if (from != null) 'from': from,
    if (to != null) 'to': to,
    'at': Timestamp.fromDate(at),
  };
}
