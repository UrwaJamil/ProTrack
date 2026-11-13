import 'package:flutter/material.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../application/helper_ranking.dart';

/// One "Who can help?" option: avatar, name, skill tags as the subtitle,
/// active-task count, and a radio mark. The selected row gets an accent
/// border.
class HelperOptionTile extends StatelessWidget {
  const HelperOptionTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final HelperCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = candidate.user;
    final skills = user.skillTags.isEmpty
        ? 'No skills listed'
        : user.skillTags.join(', ');
    final load = candidate.activeTasks;
    final radius = BorderRadius.circular(12);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? colors.secondary : colors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                UserAvatar(uid: user.uid, name: user.name, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skills,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$load active ${load == 1 ? 'task' : 'tasks'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
