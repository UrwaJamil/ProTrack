import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme_mode_menu_button.dart';
import '../../auth/presentation/widgets/sign_out_button.dart';

/// Profile tab's settings: theme, the Analytics entry point (Admins only —
/// it is no longer a nav tab) and Sign out.
class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({super.key, required this.showAnalytics});

  final bool showAnalytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('Theme'),
                subtitle: Text('Light, dark or match your device'),
                trailing: ThemeModeMenuButton(),
              ),
              if (showAnalytics) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Analytics & reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/leader/analytics'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SignOutButton(),
      ],
    );
  }
}
