import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/project.dart';
import '../../data/project_repository.dart';
import '../project_ui_actions.dart';

/// Edit-mode only: Archive / Restore and the destructive Delete link.
class ProjectDangerZone extends ConsumerStatefulWidget {
  const ProjectDangerZone({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectDangerZone> createState() => _ProjectDangerZoneState();
}

class _ProjectDangerZoneState extends ConsumerState<ProjectDangerZone> {
  bool _busy = false;

  Future<void> _toggleArchive() async {
    setState(() => _busy = true);
    final ok = await toggleProjectArchived(context, ref, widget.project);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && !widget.project.isArchived) context.pop();
  }

  Future<void> _delete() async {
    final project = widget.project;
    final repo = ref.read(projectRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (await repo.hasTasks(project.id)) {
        if (mounted) await _showHasTasks();
        return;
      }
      if (!mounted || !await _confirmDelete()) return;
      await repo.delete(project.id);
      messenger.showSnackBar(
        SnackBar(content: Text('"${project.name}" deleted')),
      );
      if (mounted) context.go('/leader/projects');
    } on ProjectHasTasksException {
      if (mounted) await _showHasTasks();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete the project. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDelete() async {
    final project = widget.project;
    final others = project.members.length - 1;
    final error = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: Text(
          'This permanently deletes ${project.shortId}'
          '${others > 0 ? ' and removes access for $others ${others == 1 ? 'member' : 'members'}' : ''}. '
          'This can\'t be undone. To keep it for reference, archive it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showHasTasks() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Can't delete this project"),
      content: const Text(
        'It still has tasks. Archive the project instead, or delete its '
        'tasks first.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final archived = widget.project.isArchived;
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _toggleArchive,
          icon: Icon(
            archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
          ),
          label: Text(archived ? 'Restore Project' : 'Archive Project'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: error),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Project'),
          ),
        ),
      ],
    );
  }
}
