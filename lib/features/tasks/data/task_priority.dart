/// `projects/{pid}/tasks/{tid}.priority`.
enum TaskPriority {
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low');

  const TaskPriority(this.value, this.label);

  /// The exact string stored in Firestore.
  final String value;

  /// What the UI shows.
  final String label;

  static TaskPriority fromValue(String? value) =>
      TaskPriority.values.firstWhere(
        (p) => p.value == value,
        orElse: () => throw FormatException('Unknown task priority: "$value"'),
      );
}
