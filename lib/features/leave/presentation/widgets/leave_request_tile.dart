import 'package:flutter/material.dart';

import '../../data/leave_request.dart';
import '../../data/working_days.dart';
import '../leave_paths.dart';
import 'leave_badges.dart';

/// One of "My requests" (mock 02): range, working days, type chip,
/// status pill and a chevron to the detail screen.
class LeaveRequestTile extends StatelessWidget {
  const LeaveRequestTile({
    super.key,
    required this.request,
    required this.onOpen,
  });

  final LeaveRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.rangeLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        LeaveStatusPill(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workingDaysLabel(request.workingDays),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 10),
                    LeaveTypeChip(type: request.type),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
