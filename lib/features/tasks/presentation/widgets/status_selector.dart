import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/task_status.dart';
import 'task_status_badge.dart';

/// FR-3.6: Not Started / In Progress / On Hold / Completed, one chip each.
/// The selected chip takes its status color. A status outside
/// [TaskStatus.choosable] (Blocked, until Phase 4) is shown selected but
/// can't be picked again.
class StatusSelector extends StatelessWidget {
  const StatusSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskStatus value;

  /// Null while a change is being saved.
  final ValueChanged<TaskStatus>? onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      ...TaskStatus.choosable,
      if (!TaskStatus.choosable.contains(value)) value,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in options)
          _StatusChip(
            status: status,
            selected: status == value,
            onSelected: onChanged == null || status == value
                ? null
                : () => onChanged!(status),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onSelected,
  });

  final TaskStatus status;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (bg, fg) = taskStatusColors(theme.appColors, status);
    final color = selected ? fg : colors.onSurfaceVariant;
    return ChoiceChip(
      selected: selected,
      // Always enabled, so a save in flight doesn't grey the chips out;
      // taps are ignored meanwhile (and on the selected chip).
      onSelected: (_) => onSelected?.call(),
      showCheckmark: false,
      avatar: Icon(taskStatusIcon(status), size: 18, color: color),
      label: Text(status.label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? fg : colors.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: bg,
      backgroundColor: colors.surface,
      side: BorderSide(
        color: selected ? fg.withValues(alpha: 0.5) : colors.outline,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
