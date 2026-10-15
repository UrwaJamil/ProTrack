/// A task's workflow status (`projects/{pid}/tasks/{tid}.status`). Defined
/// ahead of Phase 3 so project progress (FR-2.5) has its real input type.
enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  blocked('blocked'),
  completed('completed');

  const TaskStatus(this.value);

  /// The exact string stored in Firestore.
  final String value;

  static TaskStatus fromValue(String? value) => TaskStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => throw FormatException('Unknown task status: "$value"'),
  );
}
