import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_priority.dart';
import 'task_status.dart';

const taskTitleMaxLength = 100;
const taskDescriptionMaxLength = 2000;
const subtaskTitleMaxLength = 200;
const maxSubtasks = 50;

/// One portion of a task's work (FR-3.5), stored inline as
/// `subtasks[{title, done}]`.
class Subtask {
  const Subtask({required this.title, this.done = false});

  final String title;
  final bool done;

  Subtask copyWith({String? title, bool? done}) =>
      Subtask(title: title ?? this.title, done: done ?? this.done);

  factory Subtask.fromMap(Map<String, dynamic> map) => Subtask(
    title: map['title'] as String? ?? '',
    done: map['done'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {'title': title, 'done': done};

  @override
  bool operator ==(Object other) =>
      other is Subtask && other.title == title && other.done == done;

  @override
  int get hashCode => Object.hash(title, done);
}

/// `projects/{pid}/tasks/{tid}`. [projectId] comes from the document path
/// (needed for collection-group results), never from a stored field.
///
/// `helpNote` (Phase 4) and `attachments` (Phase 5) aren't modelled yet;
/// updates only touch the fields they name, so those survive untouched.
class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.priority,
    required this.status,
    required this.deadline,
    required this.subtasks,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String title;

  /// The "required work" (FR-3.3).
  final String description;
  final List<String> assignedTo;
  final TaskPriority priority;
  final TaskStatus status;

  /// A calendar date (local midnight); only the day matters.
  final DateTime deadline;
  final List<Subtask> subtasks;
  final String createdBy;
  final DateTime createdAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool isAssignedTo(String uid) => assignedTo.contains(uid);

  int get subtasksDone => subtasks.where((s) => s.done).length;

  /// "TSK-7F3K", derived from the doc id like `Project.shortId`.
  String get shortId {
    final head = id.length >= 4 ? id.substring(0, 4) : id;
    return 'TSK-${head.toUpperCase()}';
  }

  Task copyWith({TaskStatus? status, List<Subtask>? subtasks}) => Task(
    id: id,
    projectId: projectId,
    title: title,
    description: description,
    assignedTo: assignedTo,
    priority: priority,
    status: status ?? this.status,
    deadline: deadline,
    subtasks: subtasks ?? this.subtasks,
    createdBy: createdBy,
    createdAt: createdAt,
  );

  /// Throws [FormatException] for an unknown status or priority (rules
  /// prevent them; the repository skips such docs rather than guessing).
  factory Task.fromMap(String id, String projectId, Map<String, dynamic> map) {
    final rawSubtasks = map['subtasks'] as List<dynamic>? ?? const [];
    return Task(
      id: id,
      projectId: projectId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignedTo: [
        for (final uid in map['assignedTo'] as List<dynamic>? ?? const [])
          if (uid is String) uid,
      ],
      priority: TaskPriority.fromValue(map['priority'] as String?),
      status: TaskStatus.fromValue(map['status'] as String?),
      deadline: _date(map['deadline']),
      subtasks: [
        for (final s in rawSubtasks)
          if (s is Map<String, dynamic>) Subtask.fromMap(s),
      ],
      createdBy: map['createdBy'] as String? ?? '',
      // Null while a just-created doc's server timestamp is pending.
      createdAt: _date(map['createdAt'], fallback: DateTime.now()),
    );
  }

  /// This task's Admin-editable fields, e.g. to prefill the edit form.
  TaskDraft get draft => TaskDraft(
    title: title,
    description: description,
    assignedTo: assignedTo,
    priority: priority,
    status: status,
    deadline: deadline,
    subtasks: subtasks,
  );

  static List<Map<String, dynamic>> subtasksToList(List<Subtask> subtasks) => [
    for (final s in subtasks) s.toMap(),
  ];

  static DateTime _date(Object? value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// The fields an Admin sets when creating or editing a task (FR-3.1–3.3,
/// FR-3.5). `createdBy` and the timestamps are added by the repository.
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.priority,
    required this.deadline,
    this.status = TaskStatus.todo,
    this.subtasks = const [],
  });

  final String title;
  final String description;
  final List<String> assignedTo;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime deadline;
  final List<Subtask> subtasks;

  /// [includeStatus] is false for edits: status changes go through the
  /// status selector, so a stale edit form can't overwrite one an
  /// assignee made meanwhile.
  Map<String, dynamic> toMap({bool includeStatus = true}) => {
    'title': title,
    'description': description,
    'assignedTo': assignedTo,
    'priority': priority.value,
    if (includeStatus) 'status': status.value,
    'deadline': Timestamp.fromDate(deadline),
    'subtasks': Task.subtasksToList(subtasks),
  };
}
