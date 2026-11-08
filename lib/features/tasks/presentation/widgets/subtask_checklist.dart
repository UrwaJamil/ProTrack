import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/task.dart';

/// FR-3.5: the task's portions of work as a checklist with a "2 of 5 done"
/// bar. Tickable by the assignee (and project Admins) when [onToggle] is
/// set; read-only otherwise.
class SubtaskChecklist extends StatelessWidget {
  const SubtaskChecklist({
    super.key,
    required this.subtasks,
    required this.onToggle,
  });

  final List<Subtask> subtasks;

  /// (index, done); null when the viewer can't tick subtasks.
  final void Function(int index, bool done)? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final done = subtasks.where((s) => s.done).length;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: done / subtasks.length,
                      minHeight: 6,
                      color: theme.appColors.progressFill,
                      backgroundColor: theme.appColors.progressTrack,
                      semanticsLabel: 'Subtasks done',
                      semanticsValue: '${done * 100 ~/ subtasks.length}%',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$done of ${subtasks.length} done',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final (i, subtask) in subtasks.indexed)
            CheckboxListTile(
              value: subtask.done,
              onChanged: onToggle == null
                  ? null
                  : (v) => onToggle!(i, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: theme.appColors.success,
              title: Text(
                subtask.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: subtask.done
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  decoration: subtask.done ? TextDecoration.lineThrough : null,
                  decorationColor: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
