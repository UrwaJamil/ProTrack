/// Where a task's detail screen lives for this dashboard. The screen
/// itself decides what's editable from the project's `members` map.
String taskDetailPath(
  String projectId,
  String taskId, {
  required bool adminView,
}) => '${adminView ? '/leader' : '/member'}/projects/$projectId/tasks/$taskId';

/// Admin-dashboard only, like `/leader/projects/:id/edit`.
String newTaskPath(String projectId) => '/leader/projects/$projectId/tasks/new';

String editTaskPath(String projectId, String taskId) =>
    '/leader/projects/$projectId/tasks/$taskId/edit';
