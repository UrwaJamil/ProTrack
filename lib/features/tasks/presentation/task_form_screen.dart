import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/data/project.dart';
import '../application/task_permissions.dart';
import '../application/tasks_providers.dart';
import '../data/task.dart';
import '../data/task_priority.dart';
import '../data/task_repository.dart';
import 'task_paths.dart';
import 'widgets/assignee_picker.dart';
import 'widgets/subtask_editor.dart';
import 'widgets/task_form_fields.dart';

/// Create (no [taskId]) or edit a task — project Admins only (FR-3.1,
/// FR-3.2, FR-3.3, FR-3.5). Firestore rules enforce the same.
class TaskFormScreen extends ConsumerWidget {
  const TaskFormScreen({super.key, required this.projectId, this.taskId});

  final String projectId;
  final String? taskId;

  String get _title => taskId == null ? 'New Task' : 'Edit Task';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final projectAsync = ref.watch(projectProvider(projectId));
    final id = taskId;
    final taskAsync = id == null
        ? const AsyncData<Task?>(null)
        : ref.watch(taskProvider((projectId: projectId, taskId: id)));

    if (projectAsync.hasError || taskAsync.hasError) {
      return _Shell(
        title: _title,
        body: ErrorState(
          message: "We couldn't load this task.",
          onRetry: () {
            ref.invalidate(projectProvider(projectId));
            if (id != null) {
              ref.invalidate(taskProvider((projectId: projectId, taskId: id)));
            }
          },
        ),
      );
    }
    if (!projectAsync.hasValue || !taskAsync.hasValue) {
      return _Shell(
        title: _title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final project = projectAsync.value;
    final task = taskAsync.value;
    if (project == null || (id != null && task == null)) {
      return _Shell(
        title: _title,
        body: EmptyState(
          icon: Icons.search_off,
          title: project == null ? 'Project not found' : 'Task not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final permissions = TaskPermissions(project, uid, task);
    final allowed = task == null ? permissions.canCreate : permissions.canEdit;
    if (!allowed) {
      return _Shell(
        title: _title,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: project.isArchived ? 'Project archived' : 'Admins only',
          message: project.isArchived
              ? 'Restore the project to change its tasks.'
              : "Only this project's Admins can create or edit tasks.",
        ),
      );
    }
    return _FormPage(project: project, task: task);
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
  const _FormPage({required this.project, required this.task});

  final Project project;

  /// Null when creating.
  final Task? task;

  @override
  ConsumerState<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends ConsumerState<_FormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  // Only people still in the project can stay assigned.
  late List<String> _assignees = [
    for (final id in widget.task?.assignedTo ?? const <String>[])
      if (widget.project.members.containsKey(id)) id,
  ];
  late DateTime? _deadline = widget.task?.deadline;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late List<Subtask> _subtasks = widget.task?.subtasks ?? const [];
  bool _saving = false;
  String? _error;

  bool get _editing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TaskDraft get _draft => TaskDraft(
    title: _title.text.trim(),
    description: _description.text.trim(),
    assignedTo: _assignees,
    priority: _priority,
    deadline: _deadline!,
    subtasks: _subtasks,
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final projectId = widget.project.id;
    final draft = _draft;
    try {
      final task = widget.task;
      if (task == null) {
        final id = await repo.create(
          projectId,
          creatorUid: ref.read(currentUidProvider)!,
          draft: draft,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('"${draft.title}" created')),
        );
        if (mounted) {
          context.pushReplacement(
            taskDetailPath(projectId, id, adminView: true),
          );
        }
      } else {
        await repo.update(projectId, task.id, draft);
        messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
        if (mounted) context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _editing
              ? "We couldn't save your changes. Please try again."
              : "We couldn't create the task. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving;
    return _Shell(
      title: _editing ? 'Edit Task' : 'New Task',
      shortId: widget.task?.shortId,
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
                  _ProjectLine(project: widget.project),
                  const SizedBox(height: 16),
                  TaskFormFields(
                    titleController: _title,
                    descriptionController: _description,
                    deadline: _deadline,
                    onDeadlineChanged: (d) => setState(() => _deadline = d),
                    priority: _priority,
                    onPriorityChanged: (p) => setState(() => _priority = p),
                    enabled: enabled,
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Assign to',
                    child: AssigneePicker(
                      project: widget.project,
                      selected: _assignees,
                      enabled: enabled,
                      onChanged: (ids) => setState(() => _assignees = ids),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Subtasks (optional)',
                    child: SubtaskEditor(
                      initial: _subtasks,
                      enabled: enabled,
                      onChanged: (s) => _subtasks = s,
                    ),
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
                  PrimaryButton(
                    label: _editing ? 'Save Changes' : 'Create Task',
                    busy: _saving,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "In Mobile App Redesign · PRJ-7F3K", so it's clear where the task goes.
class _ProjectLine extends StatelessWidget {
  const _ProjectLine({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.folder_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            project.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        LabelPill(label: project.shortId),
      ],
    );
  }
}
