import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../data/task_comment.dart';

enum CommentAction { edit, delete }

/// One comment: avatar, name, role badge ("Admin" / "Member" in this
/// project), time, and the text in a bubble. [onAction] is null when the
/// viewer may neither edit nor delete it.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.authorName,
    required this.role,
    required this.now,
    this.canEdit = false,
    this.canDelete = false,
    this.onAction,
  });

  final TaskComment comment;
  final String authorName;

  /// The author's role in the project; null once they've left it.
  final UserRole? role;
  final DateTime now;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<CommentAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(uid: comment.authorId, name: authorName, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      authorName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (role != null) LabelPill(label: role!.label),
                    Text(
                      formatDayTime(comment.createdAt, now: now) +
                          (comment.isEdited ? ' · edited' : ''),
                      style: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _Bubble(text: comment.text),
              ],
            ),
          ),
          if (onAction != null && (canEdit || canDelete))
            PopupMenuButton<CommentAction>(
              tooltip: 'Comment options',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: onAction,
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(
                    value: CommentAction.edit,
                    child: Text('Edit'),
                  ),
                if (canDelete)
                  const PopupMenuItem(
                    value: CommentAction.delete,
                    child: Text('Delete'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: SelectableText(text, style: theme.textTheme.bodyMedium),
    );
  }
}
