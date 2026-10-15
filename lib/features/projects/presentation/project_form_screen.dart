import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/project_permissions.dart';
import '../application/projects_providers.dart';
import '../data/project.dart';
import '../data/project_repository.dart';
import 'widgets/project_danger_zone.dart';
import 'widgets/project_form_fields.dart';
import 'widgets/project_status_badge.dart';

/// Create (no [projectId]) or edit a project — Admin only (FR-2.1, FR-2.3).
/// Editing is offered only to the project's own Admins; Firestore rules
/// enforce the same.
class ProjectFormScreen extends ConsumerWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = projectId;
    if (id == null) return const _FormPage(project: null);

    final uid = ref.watch(currentUidProvider) ?? '';
    return ref
        .watch(projectProvider(id))
        .when(
          loading: () => const _Shell(
            title: 'Edit Project',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _Shell(
            title: 'Edit Project',
            body: ErrorState(
              message: "We couldn't load this project.",
              onRetry: () => ref.invalidate(projectProvider(id)),
            ),
          ),
          data: (project) {
            if (project == null) {
              return const _Shell(
                title: 'Edit Project',
                body: EmptyState(
                  icon: Icons.search_off,
                  title: 'Project not found',
                  message: 'It may have been deleted.',
                ),
              );
            }
            if (!ProjectPermissions(project, uid).isLeader) {
              return const _Shell(
                title: 'Edit Project',
                body: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Admins only',
                  message: "Only this project's Admins can edit it.",
                ),
              );
            }
            return _FormPage(project: project);
          },
        );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.title, required this.body, this.shortId});

  final String title;
  final String? shortId;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(title)),
            if (shortId != null) ...[
              const SizedBox(width: 10),
              LabelPill(label: shortId!),
            ],
          ],
        ),
      ),
      body: body,
    );
  }
}

class _FormPage extends ConsumerStatefulWidget {
  const _FormPage({required this.project});

  /// Null when creating.
  final Project? project;

  @override
  ConsumerState<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends ConsumerState<_FormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late DateTime? _start = widget.project?.startDate ?? _today();
  late DateTime? _deadline = widget.project?.deadline;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.project != null;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(projectRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final description = _description.text.trim();
    try {
      final project = widget.project;
      if (project == null) {
        final id = await repo.create(
          creatorUid: ref.read(currentUidProvider)!,
          name: name,
          description: description,
          startDate: _start!,
          deadline: _deadline!,
        );
        messenger.showSnackBar(SnackBar(content: Text('"$name" created')));
        if (mounted) context.pushReplacement('/leader/projects/$id');
      } else {
        await repo.updateDetails(
          project.id,
          name: name,
          description: description,
          startDate: _start!,
          deadline: _deadline!,
        );
        messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
        if (mounted) context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _editing
              ? "We couldn't save your changes. Please try again."
              : "We couldn't create the project. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final archived = project?.isArchived ?? false;
    return _Shell(
      title: _editing ? 'Edit Project' : 'New Project',
      shortId: project?.shortId,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (archived) ...[
                    const _ArchivedNotice(),
                    const SizedBox(height: 16),
                  ],
                  ProjectFormFields(
                    nameController: _name,
                    descriptionController: _description,
                    startDate: _start,
                    deadline: _deadline,
                    enabled: !archived && !_saving,
                    onStartChanged: (d) => setState(() => _start = d),
                    onDeadlineChanged: (d) => setState(() => _deadline = d),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!archived)
                    PrimaryButton(
                      label: _editing ? 'Save Changes' : 'Create Project',
                      busy: _saving,
                      onPressed: _submit,
                    ),
                  if (project != null) ...[
                    const SizedBox(height: 16),
                    ProjectDangerZone(project: project),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedNotice extends StatelessWidget {
  const _ArchivedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('This project is archived'),
        subtitle: Text(
          'Restore it to make changes.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
