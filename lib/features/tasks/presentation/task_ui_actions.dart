import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/task.dart';
import '../data/task_repository.dart';

/// Asks before deleting [task] (Admin only), then deletes it and leaves
/// the detail screen. Returns whether it was deleted.
Future<bool> confirmDeleteTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${task.title}"?'),
      content: const Text(
        'The task and its subtasks are removed for everyone. This can\'t '
        'be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await ref.read(taskRepositoryProvider).delete(task.projectId, task.id);
    messenger.showSnackBar(SnackBar(content: Text('"${task.title}" deleted')));
    if (router?.canPop() ?? false) router!.pop();
    return true;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't delete the task. Please try again."),
      ),
    );
    return false;
  }
}
