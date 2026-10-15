import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive_shell.dart';
import 'protrack_app_bar.dart';

/// Admin (`leader`) tabs. Analytics opens from the Profile tab and
/// notifications from the app bar bell, so neither is a tab.
const leaderDestinations = [
  NavDestinationSpec(
    icon: Icons.folder_open_outlined,
    selectedIcon: Icons.folder_open,
    label: 'Projects',
  ),
  NavDestinationSpec(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    label: 'Team',
  ),
  NavDestinationSpec(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    label: 'Calendar',
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

class LeaderShell extends StatelessWidget {
  const LeaderShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      appBar: const ProTrackAppBar(profileLocation: '/leader/profile'),
      destinations: leaderDestinations,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      body: navigationShell,
    );
  }
}
