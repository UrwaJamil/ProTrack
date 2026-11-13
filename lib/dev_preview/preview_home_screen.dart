import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme_mode_menu_button.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/app_user.dart';
import '../features/auth/presentation/widgets/role_toggle.dart';
import 'mock/mock_people.dart';
import 'preview_catalog.dart';
import 'preview_session.dart';

/// The preview's start page: the session switcher and every screen in
/// [previewEntries], grouped by role.
class PreviewHomeScreen extends ConsumerStatefulWidget {
  const PreviewHomeScreen({super.key});

  @override
  ConsumerState<PreviewHomeScreen> createState() => _PreviewHomeScreenState();
}

class _PreviewHomeScreenState extends ConsumerState<PreviewHomeScreen> {
  bool _busy = false;

  Future<void> _switchTo(UserRole role) async {
    await switchPreviewRole(
      current: ref.read(authControllerProvider),
      controller: ref.read(authControllerProvider.notifier),
      role: role,
    );
  }

  Future<void> _open(PreviewEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final role = entry.section.role;
      if (role != null) await _switchTo(role);
      if (!mounted) return;
      if (entry.tab) {
        context.go(entry.path);
      } else {
        context.push(entry.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ProTrack screen preview'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SessionCard(onSwitch: _switchTo),
              for (final section in PreviewSection.values)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _SectionList(
                    section: section,
                    entries: [
                      for (final e in previewEntries)
                        if (e.section == section) e,
                    ],
                    onOpen: _open,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.onSwitch});

  final Future<void> Function(UserRole role) onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    final role = auth.user?.uid == MockPeople.meFor(UserRole.member)
        ? UserRole.member
        : UserRole.leader;
    final status = switch (auth.status) {
      AuthStatus.authenticated =>
        'Signed in as ${profile!.name} (${profile.defaultRole.label})',
      AuthStatus.loading => 'Signing in…',
      _ => 'Signed out. Pick a role to sign back in.',
    };
    final text = Theme.of(context).textTheme;
    return _PreviewCard(
      title: 'Session',
      trailing: const ThemeModeMenuButton(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(status, style: text.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Mock data only, no Firebase. Changes last until reload. '
            'Opening a screen switches to its role automatically.',
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          RoleToggle(value: role, onChanged: onSwitch),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.section,
    required this.entries,
    required this.onOpen,
  });

  final PreviewSection section;
  final List<PreviewEntry> entries;
  final ValueChanged<PreviewEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PreviewCard(
      title: section.label,
      trailing: Text(
        '${entries.length} screens',
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.title),
              subtitle: Text(
                [entry.note, entry.path].whereType<String>().join(' · '),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.phase,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => onOpen(entry),
            ),
        ],
      ),
    );
  }
}

/// A plain card with a title row, built from the existing theme only.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
