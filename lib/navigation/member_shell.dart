import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_shell.dart';
import 'protrack_app_bar.dart';

/// Member tabs. Notifications open from the app bar bell, not a tab.
const memberDestinations = [
  NavDestinationSpec(
    icon: Icons.folder_open_outlined,
    selectedIcon: Icons.folder_open,
    label: 'Projects',
  ),
  NavDestinationSpec(
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    label: 'My Tasks',
  ),
  NavDestinationSpec(
    icon: Icons.event_busy_outlined,
    selectedIcon: Icons.event_busy,
    label: 'Leave',
  ),
  NavDestinationSpec(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profile',
  ),
];

class MemberShell extends StatelessWidget {
  const MemberShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      appBar: const ProTrackAppBar(profileLocation: '/member/profile'),
      destinations: memberDestinations,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      body: navigationShell,
    );
  }
}
