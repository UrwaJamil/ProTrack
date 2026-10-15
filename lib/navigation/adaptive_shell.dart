import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/responsive.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A dashboard shell that shows a sidebar (NavigationRail) on wide/web
/// windows and a bottom navigation bar on narrow/mobile windows, sharing a
/// single list of destinations and selection callback between both.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.appBar,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  final PreferredSizeWidget appBar;
  final List<NavDestinationSpec> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final wide = isWideScreen(context);
    final appColors = Theme.of(context).appColors;

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: appColors.sidebarBorder),
                ),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(hoverColor: appColors.sidebarHover),
                child: NavigationRail(
                  extended: MediaQuery.sizeOf(context).width >= 1100,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: MediaQuery.sizeOf(context).width >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.selected,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(hoverColor: appColors.sidebarHover),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
