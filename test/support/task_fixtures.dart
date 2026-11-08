import 'package:team_project_manager/features/tasks/data/task.dart';
import 'package:team_project_manager/features/tasks/data/task_priority.dart';
import 'package:team_project_manager/features/tasks/data/task_status.dart';

/// A task in project `abcd1234`, created by `admin` and assigned to
/// `member1`, unless told otherwise.
Task testTask({
  String id = 'tid12345',
  String projectId = 'abcd1234',
  String title = 'Design login screen',
  String description = 'Mockups for light and dark mode.',
  List<String> assignedTo = const ['member1'],
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.todo,
  DateTime? deadline,
  List<Subtask> subtasks = const [],
  String createdBy = 'admin',
}) => Task(
  id: id,
  projectId: projectId,
  title: title,
  description: description,
  assignedTo: assignedTo,
  priority: priority,
  status: status,
  deadline: deadline ?? DateTime(2026, 10, 30),
  subtasks: subtasks,
  createdBy: createdBy,
  createdAt: DateTime(2026, 10, 2),
);
