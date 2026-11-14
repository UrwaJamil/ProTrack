import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/app_user.dart';
import '../../../projects/data/project.dart';
import '../../../projects/data/project_repository.dart';

/// Active projects [me] leads that [uid] isn't in yet: the choices for
/// "Add to project".
List<Project> projectsToAddTo(
  String me,
  String uid,
  Iterable<Project> projects,
) => [
  for (final p in projects)
    if (!p.isArchived &&
        p.members[me] == UserRole.leader &&
        !p.members.containsKey(uid))
      p,
]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// Bottom sheet listing [projects]; picking one adds [uid] as a Member
/// through the existing `ProjectRepository.addMember`.
Future<void> showAddToProjectSheet(
  BuildContext context, {
  required String uid,
  required String name,
  required List<Project> projects,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => _Sheet(uid: uid, name: name, projects: projects),
);

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.uid, required this.name, required this.projects});

  final String uid;
  final String name;
  final List<Project> projects;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  String? _busyId;

  Future<void> _add(Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busyId = p.id);
    try {
      await ref.read(projectRepositoryProvider).addMember(p.id, widget.uid);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.name} added to ${p.name}.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't add them. Please try again.")),
      );
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Add ${widget.name} to a project',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in widget.projects)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(p.name),
                    subtitle: Text(p.shortId),
                    enabled: _busyId == null,
                    trailing: _busyId == p.id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    onTap: () => _add(p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
