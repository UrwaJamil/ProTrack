import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../projects/application/projects_providers.dart';
import '../../application/task_activity_providers.dart';
import '../../data/help_note.dart';
import '../../data/task_activity_repository.dart';

/// "I can help", shown only to the helper named in the help note (the
/// caller checks that). Accepting writes the `help_accepted` history entry
/// and the requester's notification in one batch; afterwards this shows
/// "You accepted this request".
class HelpAcceptButton extends ConsumerStatefulWidget {
  const HelpAcceptButton({
    super.key,
    required this.projectId,
    required this.taskId,
    required this.note,
  });

  final String projectId;
  final String taskId;

  /// Has a [HelpNote.requestId].
  final HelpNote note;

  @override
  ConsumerState<HelpAcceptButton> createState() => _HelpAcceptButtonState();
}

class _HelpAcceptButtonState extends ConsumerState<HelpAcceptButton> {
  bool _busy = false;

  HelpRequestKey get _key => (
    projectId: widget.projectId,
    taskId: widget.taskId,
    requestId: widget.note.requestId!,
  );

  Future<void> _accept() async {
    final uid = ref.read(currentUidProvider) ?? '';
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final me = await ref.read(
        userProfilesProvider(profilesKey([uid])).future,
      );
      await ref
          .read(taskActivityRepositoryProvider)
          .acceptHelp(
            widget.projectId,
            widget.taskId,
            helperUid: uid,
            helperName: me[uid]?.name ?? 'A teammate',
            note: widget.note,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Accepted. The requester was notified.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't accept the request. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = ref.watch(helpAcceptedProvider(_key));
    final theme = Theme.of(context);
    if (accepted.value ?? false) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: theme.appColors.success, size: 20),
          const SizedBox(width: 8),
          Text(
            'You accepted this request',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.appColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy || !accepted.hasValue ? null : _accept,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.volunteer_activism_outlined),
      label: const Text('I can help'),
    );
  }
}
