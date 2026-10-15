import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/project.dart';
import 'project_progress_bar.dart';
import 'project_status_badge.dart';

enum _CardAction { open, edit, toggleArchive }

/// One project in the overview list: status + short id, overflow menu,
/// name, two-line description, progress, deadline and member avatars.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.progress,
    required this.overdue,
    required this.people,
    required this.canManage,
    required this.onOpen,
    this.onEdit,
    this.onToggleArchive,
  });

  final Project project;
  final int progress;
  final bool overdue;
  final List<({String uid, String name})> people;

  /// Whether the viewer is an Admin of this project (Edit / Archive menu).
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleArchive;

  ProjectBadgeKind get _badge => project.isArchived
      ? ProjectBadgeKind.archived
      : overdue
      ? ProjectBadgeKind.overdue
      : ProjectBadgeKind.active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProjectStatusBadge(kind: _badge),
                  const SizedBox(width: 10),
                  Text(
                    project.shortId,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  _menu(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _body(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (project.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            project.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        ProjectProgressBar(progress: progress, overdue: overdue),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: overdue ? colors.error : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                formatDate(project.deadline),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: overdue ? colors.error : colors.onSurfaceVariant,
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            AvatarStack(people: people),
          ],
        ),
      ],
    );
  }

  Widget _menu() {
    return PopupMenuButton<_CardAction>(
      tooltip: 'More actions for ${project.name}',
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => switch (action) {
        _CardAction.open => onOpen(),
        _CardAction.edit => onEdit?.call(),
        _CardAction.toggleArchive => onToggleArchive?.call(),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _CardAction.open,
          child: Text('View details'),
        ),
        if (canManage && !project.isArchived)
          const PopupMenuItem(value: _CardAction.edit, child: Text('Edit')),
        if (canManage)
          PopupMenuItem(
            value: _CardAction.toggleArchive,
            child: Text(project.isArchived ? 'Restore' : 'Archive'),
          ),
      ],
    );
  }
}
