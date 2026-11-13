import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/pill_toggle.dart';
import '../../../notifications/application/recipients.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../projects/data/project.dart';
import '../../application/comment_permissions.dart';
import '../../application/task_activity_providers.dart';
import '../../application/task_permissions.dart';
import '../../application/tasks_providers.dart';
import '../../data/task.dart';
import '../../data/task_activity_repository.dart';
import '../../data/task_status.dart';
import '../task_activity_paths.dart';
import 'comment_composer.dart';
import 'help_accept_button.dart';
import 'help_note_card.dart';
import 'task_activity_header.dart';
import 'task_activity_tabs.dart';

enum ActivityTab { comments, history }

/// Header, help note, "Need help?", the Comments / History toggle, the
/// selected list and (on Comments) the composer.
class TaskActivityBody extends ConsumerStatefulWidget {
  const TaskActivityBody({
    super.key,
    required this.project,
    required this.task,
  });

  final Project project;
  final Task task;

  @override
  ConsumerState<TaskActivityBody> createState() => _TaskActivityBodyState();
}

class _TaskActivityBodyState extends ConsumerState<TaskActivityBody> {
  var _tab = ActivityTab.comments;

  TaskKey get _key =>
      (projectId: widget.task.projectId, taskId: widget.task.id);

  Future<bool> _send(String text) async {
    final uid = ref.read(currentUidProvider) ?? '';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final me = await ref.read(
        userProfilesProvider(profilesKey([uid])).future,
      );
      await ref
          .read(taskActivityRepositoryProvider)
          .addComment(
            _key.projectId,
            _key.taskId,
            authorId: uid,
            text: text,
            authorName: me[uid]?.name ?? 'A teammate',
            taskTitle: widget.task.title,
            recipients: commentRecipients(widget.project, widget.task, uid),
          );
      return true;
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't post the comment. Please try again."),
        ),
      );
      return false;
    }
  }

  void _openHelp() {
    final adminView = isAdminLocation(GoRouterState.of(context).uri.path);
    context.push(
      taskHelpPath(_key.projectId, _key.taskId, adminView: adminView),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final project = widget.project;
    final task = widget.task;
    final taskPermissions = TaskPermissions(project, uid, task);
    final commentPermissions = CommentPermissions(project, uid);
    final commentCount = ref.watch(taskCommentsProvider(_key)).value?.length;
    final note = ref.watch(taskHelpNoteProvider(_key)).value;
    final helperId = note?.taggedUserId;
    final helperName = helperId == null
        ? null
        : ref
              .watch(userProfilesProvider(profilesKey([helperId])))
              .value?[helperId]
              ?.name;
    // Only the helper named in the note, never an assignee (as the rules).
    final canAccept =
        note != null &&
        note.requestId != null &&
        note.taggedUserId == uid &&
        task.status == TaskStatus.blocked &&
        !project.isArchived &&
        project.members.containsKey(uid) &&
        !task.isAssignedTo(uid);
    final canAskForHelp = taskPermissions.canUpdateStatus && !task.isCompleted;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskActivityHeader(task: task, project: project),
                  if (task.status == TaskStatus.blocked && note != null) ...[
                    const SizedBox(height: 12),
                    HelpNoteCard(note: note, helperName: helperName),
                  ],
                  if (canAccept) ...[
                    const SizedBox(height: 12),
                    HelpAcceptButton(
                      projectId: _key.projectId,
                      taskId: _key.taskId,
                      note: note,
                    ),
                  ],
                  if (canAskForHelp) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openHelp,
                      icon: const Icon(Icons.support_outlined),
                      label: Text(
                        task.status == TaskStatus.blocked
                            ? 'Update help request'
                            : 'Need help?',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  PillToggle<ActivityTab>(
                    value: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                    segments: [
                      PillSegment(
                        value: ActivityTab.comments,
                        label: commentCount == null
                            ? 'Comments'
                            : 'Comments ($commentCount)',
                      ),
                      const PillSegment(
                        value: ActivityTab.history,
                        label: 'History',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                ActivityTab.comments => CommentsTab(
                  taskKey: _key,
                  project: project,
                  permissions: commentPermissions,
                ),
                ActivityTab.history => HistoryTab(taskKey: _key),
              },
            ),
            if (_tab == ActivityTab.comments && commentPermissions.canComment)
              CommentComposer(onSend: _send),
          ],
        ),
      ),
    );
  }
}
