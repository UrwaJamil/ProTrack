import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../notifications/application/recipients.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../projects/data/project.dart';
import '../../application/helper_ranking.dart';
import '../../application/task_activity_providers.dart';
import '../../application/tasks_providers.dart';
import '../../data/help_note.dart';
import '../../data/task.dart';
import '../../data/task_activity_repository.dart';
import 'helper_list.dart';
import 'task_activity_header.dart';

/// Banner, related task, "What is blocking you?", "Who can help?" and
/// Request Help. An existing help note pre-fills the form.
class NeedHelpForm extends ConsumerStatefulWidget {
  const NeedHelpForm({super.key, required this.project, required this.task});

  final Project project;
  final Task task;

  @override
  ConsumerState<NeedHelpForm> createState() => _NeedHelpFormState();
}

class _NeedHelpFormState extends ConsumerState<NeedHelpForm> {
  final _text = TextEditingController();
  String? _helperId;
  bool _touched = false;
  bool _sending = false;

  TaskKey get _key =>
      (projectId: widget.task.projectId, taskId: widget.task.id);

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    // Pre-fill from the current help note once it arrives, unless the
    // user has started typing.
    ref.listenManual(taskHelpNoteProvider(_key), (_, next) {
      final note = next.value;
      if (note == null || _touched) return;
      _touched = true;
      _text.text = note.text;
      setState(() => _helperId = note.taggedUserId);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool _canSend(List<HelperCandidate>? helpers) =>
      !_sending &&
      _text.text.trim().isNotEmpty &&
      helpers != null &&
      (helpers.isEmpty || helpers.any((h) => h.user.uid == _helperId));

  Future<void> _send() async {
    final uid = ref.read(currentUidProvider) ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _sending = true);
    try {
      final me = await ref.read(
        userProfilesProvider(profilesKey([uid])).future,
      );
      await ref
          .read(taskActivityRepositoryProvider)
          .requestHelp(
            _key.projectId,
            _key.taskId,
            requesterUid: uid,
            requesterName: me[uid]?.name ?? 'A teammate',
            taskTitle: widget.task.title,
            previousStatus: widget.task.status,
            note: HelpNote(text: _text.text.trim(), taggedUserId: _helperId),
            adminIds: blockedRecipients(
              widget.project,
              requesterUid: uid,
              helperUid: _helperId,
            ),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Help requested. Task marked Blocked.')),
      );
      if (router.canPop()) router.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't send the request. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final helpersAsync = ref.watch(helperCandidatesProvider(_key));
    final helpers = helpersAsync.value;
    final helperName = helpers
        ?.where((h) => h.user.uid == _helperId)
        .firstOrNull
        ?.user
        .name;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _InfoBanner(),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TaskActivityHeader(
                  task: widget.task,
                  project: widget.project,
                  caption: 'RELATED TASK',
                ),
              ),
            ),
            const SizedBox(height: 20),
            LabeledField(
              label: 'What is blocking you?  (Required)',
              child: TextField(
                controller: _text,
                enabled: !_sending,
                minLines: 4,
                maxLines: 8,
                maxLength: helpNoteMaxLength,
                onChanged: (_) => _touched = true,
                decoration: InputDecoration(
                  hintText: 'Describe the problem and what you tried.',
                  counterText: '${_text.text.length} characters',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Who can help?',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            HelperList(
              async: helpersAsync,
              selectedId: _helperId,
              enabled: !_sending,
              onSelect: (uid) => setState(() => _helperId = uid),
              onRetry: () {
                ref.invalidate(projectProvider(_key.projectId));
                ref.invalidate(projectTasksProvider(_key.projectId));
                ref.invalidate(
                  userProfilesProvider(profilesKey(widget.project.memberIds)),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: PrimaryButton(
                label: 'Request Help',
                busy: _sending,
                onPressed: _canSend(helpers) ? _send : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helperName == null
                  ? 'The task will be marked Blocked.'
                  : '$helperName will be notified with this task attached.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.support_agent, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Unblocking teammates is a priority. Say where you're stuck "
              'and pick someone to help.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
