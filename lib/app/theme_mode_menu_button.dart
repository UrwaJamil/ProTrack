import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

/// App-bar action for switching between Light / Dark / System theme mode.
/// Placed in both the Admin (leader) and Member dashboard shells.
class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(_iconFor(mode)),
      initialValue: mode,
      onSelected: (selected) =>
          ref.read(themeModeProvider.notifier).setThemeMode(selected),
      itemBuilder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return [
          _entry(
            context,
            mode: ThemeMode.light,
            current: mode,
            label: 'Light',
            icon: Icons.light_mode_outlined,
            colorScheme: colorScheme,
          ),
          _entry(
            context,
            mode: ThemeMode.dark,
            current: mode,
            label: 'Dark',
            icon: Icons.dark_mode_outlined,
            colorScheme: colorScheme,
          ),
          _entry(
            context,
            mode: ThemeMode.system,
            current: mode,
            label: 'System',
            icon: Icons.brightness_auto_outlined,
            colorScheme: colorScheme,
          ),
        ];
      },
    );
  }

  PopupMenuItem<ThemeMode> _entry(
    BuildContext context, {
    required ThemeMode mode,
    required ThemeMode current,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final selected = mode == current;
    // The popup surface isn't the top bar, so its icons/text must use the
    // normal on-surface theme color for that surface, not whatever
    // IconTheme happens to be ambient where the button lives (the top bar's
    // fixed foreground color, which is unreadable on a light popup).
    final color = selected ? colorScheme.primary : colorScheme.onSurface;

    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: color))),
          if (selected) Icon(Icons.check, size: 20, color: colorScheme.primary),
        ],
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };
}
