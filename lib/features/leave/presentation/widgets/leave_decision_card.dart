import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../team/application/team_providers.dart';
import '../../application/approvers.dart';
import '../../data/leave_repository.dart';
import '../../data/leave_request.dart';
import '../../data/working_days.dart';
import '../leave_paths.dart';
import 'deadline_conflict_warning.dart';
import 'leave_badges.dart';

/// One request on Leave Management (mock 03): avatar, name, dates, type,
/// quoted reason, the requester's tasks due during the leave, and Reject
/// / Approve while pending (status and decider in History).
class LeaveDecisionCard extends ConsumerStatefulWidget {
  const LeaveDecisionCard({
    super.key,
    required this.request,
    required this.profiles,
  });

  final LeaveRequest request;
  final Map<String, AppUser> profiles;

  @override
  ConsumerState<LeaveDecisionCard> createState() => _LeaveDecisionCardState();
}

class _LeaveDecisionCardState extends ConsumerState<LeaveDecisionCard> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    final me = ref.read(currentUidProvider) ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final r = widget.request;
    final project = decidingProjectFor(
      me,
      r.userId,
      ref.read(myProjectsProvider).value ?? const [],
    );
    if (project == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "You no longer lead a project with this member, so you can't "
            'decide this request.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final profiles = await ref.read(
        userProfilesProvider(profilesKey([me])).future,
      );
      await ref
          .read(leaveRepositoryProvider)
          .decide(
            r,
            approve: approve,
            deciderUid: me,
            deciderName: profiles[me]?.name ?? 'An Admin',
            projectId: project.id,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Leave approved.' : 'Leave rejected.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the decision. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final name = widget.profiles[r.userId]?.name ?? 'Unknown member';
    final tasks = ref.watch(teamTasksProvider).value ?? const [];
    final conflicts = r.isPending
        ? tasksDueDuring(
            tasks.map((t) => t.task),
            uid: r.userId,
            from: r.fromDate,
            to: r.toDate,
          )
        : const <Never>[];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(request: r, name: name),
            const SizedBox(height: 10),
            if (r.reason.isNotEmpty) _Reason(r.reason),
            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: 10),
              DeadlineConflictWarning(tasks: [...conflicts], whose: "$name's"),
            ],
            const SizedBox(height: 12),
            if (r.isPending)
              _Actions(
                busy: _busy,
                onReject: () => _decide(approve: false),
                onApprove: () => _decide(approve: true),
              )
            else
              _Decided(request: r, profiles: widget.profiles),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.request, required this.name});

  final LeaveRequest request;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        UserAvatar(uid: request.userId, name: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13, color: muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${request.rangeLabel} · '
                      '${workingDaysLabel(request.workingDays)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        LeaveTypeChip(type: request.type),
      ],
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.appColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '“$reason”',
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.busy,
    required this.onReject,
    required this.onApprove,
  });

  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error.withValues(alpha: 0.5)),
            ),
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onApprove,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }
}

class _Decided extends StatelessWidget {
  const _Decided({required this.request, required this.profiles});

  final LeaveRequest request;
  final Map<String, AppUser> profiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final by = profiles[request.decidedBy]?.name;
    final at = request.decidedAt;
    return Row(
      children: [
        LeaveStatusPill(status: request.status),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            [
              if (by != null) 'by $by',
              if (at != null) formatDate(at),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
