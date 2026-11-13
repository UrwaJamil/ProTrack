import 'package:flutter/material.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../leave/presentation/widgets/leave_badges.dart';
import '../../application/team_providers.dart';

/// One Team row (mock 04): avatar, name, role, On Leave badge and
/// "n active tasks".
class TeamMemberRow extends StatelessWidget {
  const TeamMemberRow({super.key, required this.member, required this.onOpen});

  final TeamMember member;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final n = member.activeTasks;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              UserAvatar(uid: member.user.uid, name: member.user.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.role.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$n active ${n == 1 ? 'task' : 'tasks'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  OnLeaveIndicator(uid: member.user.uid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
