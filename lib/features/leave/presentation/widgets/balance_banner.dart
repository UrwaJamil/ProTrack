import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/leave_type.dart';
import '../../data/working_days.dart';

/// "Available Casual Leave · 8.5 days · FY 2026" (mock 02). [available]
/// is `null` for "Other", which has no balance.
class BalanceBanner extends StatelessWidget {
  const BalanceBanner({
    super.key,
    required this.type,
    required this.available,
    required this.year,
  });

  final LeaveType type;
  final num? available;
  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = available;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.appColors.chipBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, color: theme.appColors.chipText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  days == null
                      ? '${type.label} leave'
                      : 'Available ${type.label} Leave',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  days == null
                      ? 'No yearly limit'
                      : '${formatDays(days)} ${days == 1 ? 'day' : 'days'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          LabelPill(label: 'FY $year'),
        ],
      ),
    );
  }
}
