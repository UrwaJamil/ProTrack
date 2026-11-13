import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/relative_time.dart';
import '../../data/app_notification.dart';

/// Icon per type, so a notice doesn't rely on its text alone.
IconData notificationIcon(NotificationType type) => switch (type) {
  NotificationType.helpRequested => Icons.support_outlined,
  NotificationType.helpAccepted => Icons.handshake_outlined,
  NotificationType.taskBlocked => Icons.block,
  NotificationType.commentAdded => Icons.chat_bubble_outline,
  NotificationType.leaveRequested => Icons.event_note_outlined,
  NotificationType.leaveApproved => Icons.event_available_outlined,
  NotificationType.leaveRejected => Icons.event_busy_outlined,
};

/// One notice (mocks 01 / 03): icon in a circle (with a dot while
/// unread), message, a subtitle (the comment quoted, else [detail] or the
/// project name) and the relative time. Unread notices are tinted.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.now,
    required this.onTap,
    this.projectName,
  });

  final AppNotification notification;
  final DateTime now;
  final String? projectName;

  /// Marks the notice read and opens its target, if any.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final n = notification;
    final unread = !n.read;
    final subtitle = _subtitle();

    return Semantics(
      label: unread ? 'Unread' : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: unread ? theme.appColors.chipBackground : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Icon(type: n.type, unread: unread),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: n.type == NotificationType.commentAdded
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatRelativeTime(n.createdAt, now: now),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _subtitle() {
    final detail = notification.detail;
    if (notification.type == NotificationType.commentAdded &&
        detail != null &&
        detail.isNotEmpty) {
      return '“$detail”';
    }
    final parts = [
      ?projectName,
      if (detail != null && detail.isNotEmpty) detail,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.type, required this.unread});

  final NotificationType type;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unread ? colors.primary : colors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outline),
            ),
            child: Icon(
              notificationIcon(type),
              size: 20,
              color: unread ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
          if (unread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                key: const ValueKey('unread-dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
