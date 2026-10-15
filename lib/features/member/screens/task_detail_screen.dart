import 'package:flutter/material.dart';

import '../../common/placeholder_content.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.projectId,
    required this.taskId,
  });

  final String projectId;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task: $taskId')),
      body: PlaceholderContent(
        icon: Icons.task_outlined,
        message:
            'Task Detail\n(status update, help-needed note,\nsub-tasks, attachments, comments)\ncoming in a later phase',
      ),
    );
  }
}
