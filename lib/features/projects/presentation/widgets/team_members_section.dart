import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../application/project_permissions.dart';
import '../../application/projects_providers.dart';
import '../../data/project.dart';
import '../../data/project_repository.dart';
import 'project_status_badge.dart';

/// "Team Members (N)" with "+ Add" for Admins, and one row per member:
/// Admins show a lock (they can't be removed); Members show a remove
/// button to project Admins (FR-2.2).
class TeamMembersSection extends ConsumerWidget {
  const TeamMembersSection({
    super.key,
    required this.project,
    required this.permissions,
    this.onAdd,
  });

  final Project project;
  final ProjectPermissions permissions;

  /// Shown as "+ Add" when set (Admins of an active project).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(
      userProfilesProvider(profilesKey(project.memberIds)),
    );
    final known = profiles.value ?? const <String, AppUser>{};
    final ordered = _ordered(known);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Team Members',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            LabelPill(label: '${project.members.length}'),
            const Spacer(),
            if (onAdd != null)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: profiles.isLoading && known.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: [
                    for (var i = 0; i < ordered.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _MemberRow(
                        uid: ordered[i],
                        profile: known[ordered[i]],
                        project: project,
                        permissions: permissions,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Creator first, then other Admins, then Members, each by name.
  List<String> _ordered(Map<String, AppUser> profiles) {
    int rank(String id) => id == project.createdBy
        ? 0
        : project.members[id] == UserRole.leader
        ? 1
        : 2;
    String name(String id) => (profiles[id]?.name ?? '').toLowerCase();
    return project.memberIds..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : name(a).compareTo(name(b));
    });
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.uid,
    required this.profile,
    required this.project,
    required this.permissions,
  });

  final String uid;
  final AppUser? profile;
  final Project project;
  final ProjectPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final role = project.members[uid]!;
    final isYou = uid == permissions.uid;
    final name = profile?.name ?? 'Unknown user';

    return ListTile(
      leading: UserAvatar(uid: uid, name: profile?.name ?? '', size: 40),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isYou ? '$name (you)' : name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _RoleBadge(role: role),
        ],
      ),
      subtitle: Text(
        profile?.email ?? '',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: role == UserRole.leader
          ? Tooltip(
              message: "Admins can't be removed",
              child: Icon(
                Icons.lock_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : permissions.canRemoveMember(uid)
          ? IconButton(
              tooltip: 'Remove $name',
              icon: Icon(
                Icons.person_remove_outlined,
                color: theme.colorScheme.error,
              ),
              onPressed: () => _remove(context, ref, name),
            )
          : null,
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          'They will lose access to "${project.name}". You can add them '
          'again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(projectRepositoryProvider).removeMember(project.id, uid);
      messenger.showSnackBar(SnackBar(content: Text('$name removed')));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't remove $name. Please try again.")),
      );
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = role == UserRole.leader;
    final (bg, fg) = admin
        ? (theme.colorScheme.primary, theme.colorScheme.onPrimary)
        : (theme.appColors.chipBackground, theme.appColors.chipText);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      // `label` is the display wording (Admin/Member), never the stored
      // value (CLAUDE.md decision 1).
      child: Text(
        role.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
