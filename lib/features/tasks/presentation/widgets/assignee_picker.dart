import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../projects/data/project.dart';

/// FR-3.2: pick one or more of the project's people as assignees. Takes
/// part in [Form] validation (at least one is required).
class AssigneePicker extends ConsumerWidget {
  const AssigneePicker({
    super.key,
    required this.project,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final Project project;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(
      userProfilesProvider(profilesKey(project.memberIds)),
    );
    final profiles = async.value ?? const <String, AppUser>{};
    final people = _ordered(profiles);

    return FormField<List<String>>(
      validator: (_) =>
          selected.isEmpty ? 'Assign at least one team member' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (async.isLoading && profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in people)
                  _PersonChip(
                    uid: id,
                    name: profiles[id]?.name ?? 'Unknown user',
                    isAdmin: project.members[id] == UserRole.leader,
                    selected: selected.contains(id),
                    onSelected: enabled
                        ? (on) {
                            onChanged(
                              on
                                  ? [...selected, id]
                                  : selected.where((s) => s != id).toList(),
                            );
                            field.didChange(null);
                          }
                        : null,
                  ),
              ],
            ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                field.errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Members first (they do most of the work), then Admins, each by name.
  List<String> _ordered(Map<String, AppUser> profiles) {
    int rank(String id) => project.members[id] == UserRole.leader ? 1 : 0;
    String name(String id) => (profiles[id]?.name ?? '').toLowerCase();
    return project.memberIds..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : name(a).compareTo(name(b));
    });
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.uid,
    required this.name,
    required this.isAdmin,
    required this.selected,
    required this.onSelected,
  });

  final String uid;
  final String name;
  final bool isAdmin;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    return FilterChip(
      avatar: UserAvatar(uid: uid, name: name, size: 24),
      // Display wording (Admin), never the stored role value.
      label: Text(isAdmin ? '$name · ${UserRole.leader.label}' : name),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: appColors.chipBackground,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.secondary
            : theme.colorScheme.outline,
        width: selected ? 1.5 : 1,
      ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? appColors.chipText : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
