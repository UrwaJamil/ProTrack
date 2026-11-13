import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/on_leave_badge.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../application/leave_providers.dart';
import '../../data/leave_type.dart';

/// [OnLeaveBadge] when [uid] is on approved leave today, else nothing.
/// The hook for any list of people (Team, Member Profile; later the
/// members list and assignee picker, see docs/PLAN.md).
class OnLeaveIndicator extends ConsumerWidget {
  const OnLeaveIndicator({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(onLeaveTodayProvider).contains(uid)
      ? const OnLeaveBadge()
      : const SizedBox.shrink();
}

/// "● Pending" / "● Approved" / "● Rejected".
class LeaveStatusPill extends StatelessWidget {
  const LeaveStatusPill({super.key, required this.status});

  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.appColors;
    final error = theme.colorScheme.error;
    final (Color? bg, Color? border, Color fg) = switch (status) {
      LeaveStatus.pending => (
        c.statusInProgressBackground,
        null,
        c.statusInProgressText,
      ),
      LeaveStatus.approved => (
        c.statusCompletedBackground,
        null,
        c.statusCompletedText,
      ),
      // Outline, not fill, like OverdueBadge (contrast of small red text).
      LeaveStatus.rejected => (null, error.withValues(alpha: 0.45), error),
    };
    return StatusPill(
      background: bg,
      border: border,
      children: [
        Icon(Icons.circle, size: 7, color: fg),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The leave type as a small chip ("Casual").
class LeaveTypeChip extends StatelessWidget {
  const LeaveTypeChip({super.key, required this.type});

  final LeaveType type;

  @override
  Widget build(BuildContext context) => LabelPill(label: type.label);
}
