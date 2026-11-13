import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/task_history_entry.dart';
import '../../data/task_status.dart';

/// "requested help from Zain Ahmed", "changed status to In Progress", …
/// — the part after the actor's name. [nameOf] resolves uids.
String describeHistory(
  TaskHistoryEntry entry,
  String Function(String uid) nameOf,
) {
  String status(String? value) {
    try {
      return TaskStatus.fromValue(value).label;
    } on FormatException {
      return value ?? '';
    }
  }

  final to = entry.to;
  return switch (entry.action) {
    HistoryAction.created => 'created task',
    HistoryAction.statusChanged => 'changed status to ${status(to)}',
    HistoryAction.edited => 'edited the task',
    HistoryAction.reassigned =>
      to == null ? 'reassigned the task' : 'reassigned task to ${nameOf(to)}',
    HistoryAction.subtaskCompleted =>
      to == null ? 'completed a subtask' : 'completed subtask $to',
    HistoryAction.helpRequested =>
      to == null ? 'requested help' : 'requested help from ${nameOf(to)}',
    HistoryAction.helpAccepted =>
      to == null
          ? 'accepted the help request'
          : "accepted ${nameOf(to)}'s help request",
  };
}

/// One history row: avatar, the actor's name plus [describeHistory], and
/// when.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.entry,
    required this.nameOf,
    required this.now,
  });

  final TaskHistoryEntry entry;
  final String Function(String uid) nameOf;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = nameOf(entry.who);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(uid: entry.who, name: name, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${describeHistory(entry, nameOf)}'),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatDayTime(entry.at, now: now),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
