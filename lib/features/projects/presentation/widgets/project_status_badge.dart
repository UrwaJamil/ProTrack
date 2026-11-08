import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/status_pill.dart';

enum ProjectBadgeKind { active, overdue, archived }

/// "● Active", "⚠ Overdue" ([OverdueBadge]) or "Archived".
class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({super.key, required this.kind});

  final ProjectBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.appColors;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return switch (kind) {
      ProjectBadgeKind.active => StatusPill(
        background: appColors.success.withValues(alpha: 0.12),
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: appColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('Active', style: style?.copyWith(color: colors.onSurface)),
        ],
      ),
      ProjectBadgeKind.overdue => const OverdueBadge(),
      ProjectBadgeKind.archived => StatusPill(
        background: appColors.statusToDoBackground,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 14,
            color: appColors.statusToDoText,
          ),
          const SizedBox(width: 5),
          Text(
            'Archived',
            style: style?.copyWith(color: appColors.statusToDoText),
          ),
        ],
      ),
    };
  }
}
