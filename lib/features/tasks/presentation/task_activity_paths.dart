import 'task_paths.dart';

/// Comments / History for a task, under its detail route on either
/// dashboard (Phase 4).
String taskActivityPath(
  String projectId,
  String taskId, {
  required bool adminView,
}) => '${taskDetailPath(projectId, taskId, adminView: adminView)}/activity';

/// Need Help, opened from the Comments / History screen (Phase 4).
String taskHelpPath(
  String projectId,
  String taskId, {
  required bool adminView,
}) => '${taskDetailPath(projectId, taskId, adminView: adminView)}/help';

/// Whether a location is on the Admin dashboard, so screens reached from a
/// task keep the dashboard they were opened from.
bool isAdminLocation(String location) => location.startsWith('/leader');
