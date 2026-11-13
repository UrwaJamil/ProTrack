import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/state_views.dart';
import '../../../auth/data/app_user.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../projects/data/project.dart';
import '../../application/comment_permissions.dart';
import '../../application/task_activity_providers.dart';
import '../../application/tasks_providers.dart';
import '../../data/task_activity_repository.dart';
import '../../data/task_comment.dart';
import '../../data/task_history_entry.dart';
import 'comment_dialogs.dart';
import 'comment_tile.dart';
import 'history_tile.dart';

/// Names for [uids]; "Former member" while unknown or deleted.
String Function(String) _namesFrom(Map<String, AppUser>? profiles) =>
    (uid) => profiles?[uid]?.name ?? 'Former member';

/// The comment list, oldest first.
class CommentsTab extends ConsumerWidget {
  const CommentsTab({
    super.key,
    required this.taskKey,
    required this.project,
    required this.permissions,
  });

  final TaskKey taskKey;
  final Project project;
  final CommentPermissions permissions;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    TaskComment comment,
    CommentAction action,
  ) async {
    final repo = ref.read(taskActivityRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case CommentAction.edit:
          final text = await showEditCommentDialog(context, comment.text);
          if (text == null) return;
          await repo.editComment(
            taskKey.projectId,
            taskKey.taskId,
            comment.id,
            text,
          );
        case CommentAction.delete:
          if (!await confirmDeleteComment(context)) return;
          await repo.deleteComment(
            taskKey.projectId,
            taskKey.taskId,
            comment.id,
          );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the change. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskCommentsProvider(taskKey));
    final comments = async.value;
    final names = comments == null
        ? null
        : ref
              .watch(
                userProfilesProvider(
                  profilesKey(comments.map((c) => c.authorId)),
                ),
              )
              .value;
    final now = ref.watch(todayProvider);

    if (async.hasError) {
      return ErrorState(
        message: "We couldn't load the comments.",
        onRetry: () => ref.invalidate(taskCommentsProvider(taskKey)),
      );
    }
    if (comments == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (comments.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No comments yet',
        message: permissions.canComment
            ? 'Start the conversation about this task.'
            : null,
      );
    }
    final nameOf = _namesFrom(names);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
      itemCount: comments.length,
      itemBuilder: (context, i) {
        final c = comments[i];
        return CommentTile(
          comment: c,
          authorName: nameOf(c.authorId),
          role: project.members[c.authorId],
          now: now,
          canEdit: permissions.canEdit(c),
          canDelete: permissions.canDelete(c),
          onAction: (a) => _onAction(context, ref, c, a),
        );
      },
    );
  }
}

/// The history list, newest first, [historyPageSize] at a time.
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key, required this.taskKey});

  final TaskKey taskKey;

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  var _limit = historyPageSize;

  /// The last page shown, kept while "Load more" fetches the bigger one so
  /// the list doesn't flash to a spinner.
  List<TaskHistoryEntry>? _shown;

  HistoryKey get _key => (
    projectId: widget.taskKey.projectId,
    taskId: widget.taskKey.taskId,
    limit: _limit,
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskHistoryProvider(_key));
    final entries = _shown = async.value ?? _shown;
    final uids = {
      for (final e in entries ?? const <TaskHistoryEntry>[]) ...[e.who, ?e.to],
    };
    final names = ref.watch(userProfilesProvider(profilesKey(uids))).value;
    final now = ref.watch(todayProvider);

    if (async.hasError) {
      return ErrorState(
        message: "We couldn't load the history.",
        onRetry: () => ref.invalidate(taskHistoryProvider(_key)),
      );
    }
    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No history yet',
        message:
            'Help requests show up here. Other changes will be added '
            'in a later update.',
      );
    }
    final hasMore = entries.length >= _limit;
    final nameOf = _namesFrom(names);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final e in entries)
          HistoryTile(entry: e, nameOf: nameOf, now: now),
        if (hasMore)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _limit += historyPageSize),
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }
}
