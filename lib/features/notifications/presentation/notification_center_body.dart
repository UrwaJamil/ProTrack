import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/notification_center_providers.dart';
import '../data/app_notification.dart';
import '../data/notification_repository.dart';
import 'widgets/notification_tile.dart';

/// The notification center (mocks 01 / 03), shown by the
/// `NotificationsScreen` placeholder for both roles: "Notifications" with
/// an "n new" chip, Mark all as read, the list, and a caught-up footer.
class NotificationCenterBody extends ConsumerWidget {
  const NotificationCenterBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(myNotificationsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(
            message: "We couldn't load your notifications.",
            onRetry: () => ref.invalidate(myNotificationsProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No notifications yet',
                  message:
                      'Help requests, comments and leave updates show up '
                      'here.',
                )
              : _List(items: list),
        );
  }
}

class _List extends ConsumerStatefulWidget {
  const _List({required this.items});

  final List<AppNotification> items;

  @override
  ConsumerState<_List> createState() => _ListState();
}

class _ListState extends ConsumerState<_List> {
  bool _markingAll = false;

  Future<void> _markAll() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(uid);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't update. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    final router = GoRouter.of(context);
    final target = notificationTarget(n, ref.read(notificationRoleProvider));
    if (!n.read) {
      // Best effort: opening the target matters more than the flag.
      ref
          .read(notificationRepositoryProvider)
          .markRead(n.id)
          .catchError((Object _) {});
    }
    if (target != null) router.push(target);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final unread = items.where((n) => !n.read).length;
    final now = ref.watch(todayProvider);
    final projectNames = {
      for (final p in ref.watch(myProjectsProvider).value ?? const [])
        p.id: p.name,
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Header(
              unread: unread,
              busy: _markingAll,
              onMarkAll: unread == 0 ? null : _markAll,
            ),
            const SizedBox(height: 12),
            for (final (i, n) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              NotificationTile(
                key: ValueKey(n.id),
                notification: n,
                now: now,
                projectName: projectNames[n.projectId],
                onTap: () => _open(n),
              ),
            ],
            if (unread == 0) const _CaughtUp(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.busy,
    required this.onMarkAll,
  });

  final int unread;
  final bool busy;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Title and chip wrap under each other on narrow phones, so the
    // button always fits.
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Notifications',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.appColors.chipBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unread new',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.appColors.chipText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: busy ? null : onMarkAll,
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark all as read'),
        ),
      ],
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(Icons.done_all, color: muted),
          const SizedBox(height: 6),
          Text(
            "You're completely caught up with your team.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
