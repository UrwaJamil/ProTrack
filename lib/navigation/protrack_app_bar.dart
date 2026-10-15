import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/widgets/app_logo.dart';
import '../core/widgets/user_avatar.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/notifications/application/notification_providers.dart';

/// Dashboard top bar for both roles: logo + "ProTrack", search, the
/// notifications bell (with an unread dot) and the user's avatar, which
/// opens the Profile tab at [profileLocation].
class ProTrackAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ProTrackAppBar({super.key, required this.profileLocation});

  final String profileLocation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final profile = ref.watch(authControllerProvider).profile;
    final unread = ref.watch(unreadNotificationCountProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          AppLogo(size: 32, borderColor: appColors.sidebarBorder),
          const SizedBox(width: 10),
          const Text(
            appName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Search arrives in a later phase.')),
            ),
        ),
        IconButton(
          tooltip: unread > 0
              ? 'Notifications, $unread unread'
              : 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            smallSize: 9,
            backgroundColor: theme.colorScheme.error,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        if (profile != null)
          IconButton(
            tooltip: 'Your profile',
            onPressed: () => context.go(profileLocation),
            icon: UserAvatar(uid: profile.uid, name: profile.name, size: 32),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
