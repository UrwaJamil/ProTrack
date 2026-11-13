import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../application/leave_providers.dart';
import '../data/leave_repository.dart';
import '../data/leave_request.dart';
import '../data/working_days.dart';
import 'leave_paths.dart';
import 'widgets/leave_badges.dart';

/// One of the Member's requests (`/member/leave/:leaveId`). No mock; it
/// follows mock 02's style. Cancel is offered while pending.
class LeaveDetailScreen extends ConsumerWidget {
  const LeaveDetailScreen({super.key, required this.leaveId});

  final String leaveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveRequestProvider(leaveId));
    final Widget body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(
        message: "We couldn't load this request.",
        onRetry: () => ref.invalidate(leaveRequestProvider(leaveId)),
      ),
      data: (r) => r == null
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'Request not found',
              message: 'It may have been cancelled.',
            )
          : _Details(request: r),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: body,
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final decider = request.decidedBy;
    final profiles =
        ref.watch(userProfilesProvider(profilesKey([?decider]))).value ??
        const <String, AppUser>{};
    final deciderName = decider == null ? null : profiles[decider]?.name;
    final decidedAt = request.decidedAt;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.rangeLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        LeaveStatusPill(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workingDaysLabel(request.workingDays) +
                          (request.halfDay ? ' (half day)' : ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LeaveTypeChip(type: request.type),
                    const Divider(height: 28),
                    _Field('Reason', request.reason),
                    _Field('Requested', formatDate(request.createdAt)),
                    if (!request.isPending)
                      _Field(
                        request.status.label,
                        [
                          if (deciderName != null) 'by $deciderName',
                          if (decidedAt != null) 'on ${formatDate(decidedAt)}',
                        ].join(' '),
                      ),
                  ],
                ),
              ),
            ),
            if (request.isPending) ...[
              const SizedBox(height: 20),
              _CancelButton(request: request),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.request});

  final LeaveRequest request;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(
          'Your ${widget.request.type.label} leave request for '
          '${widget.request.rangeLabel} will be withdrawn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(leaveRepositoryProvider).cancel(widget.request.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Leave request cancelled.')),
      );
      if (router.canPop()) router.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't cancel. It may already have been decided."),
        ),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error.withValues(alpha: 0.6)),
        ),
        onPressed: _busy ? null : _cancel,
        icon: const Icon(Icons.close),
        label: const Text('Cancel request'),
      ),
    );
  }
}
