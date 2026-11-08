/// A task's workflow status (`projects/{pid}/tasks/{tid}.status`).
///
/// FR-3.6's wording maps onto the stored values through [label]: `todo` is
/// shown as "Not Started", `on_hold` as "On Hold". `blocked` is a separate
/// state reserved for Phase 4's help-note flow ("needs help", unlike a
/// deliberate pause), so it isn't offered in [choosable] yet.
enum TaskStatus {
  todo('todo', 'Not Started'),
  inProgress('in_progress', 'In Progress'),
  onHold('on_hold', 'On Hold'),
  blocked('blocked', 'Blocked'),
  completed('completed', 'Completed');

  const TaskStatus(this.value, this.label);

  /// The exact string stored in Firestore.
  final String value;

  /// What the UI shows; never show [value] or [name].
  final String label;

  /// The statuses a user can pick (FR-3.6). Phase 4 adds [blocked].
  static const choosable = [todo, inProgress, onHold, completed];

  static TaskStatus fromValue(String? value) => TaskStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => throw FormatException('Unknown task status: "$value"'),
  );
}
