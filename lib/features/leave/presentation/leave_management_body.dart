import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/pill_toggle.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/app_user.dart';
import '../../projects/application/projects_providers.dart';
import '../application/leave_providers.dart';
import '../data/leave_request.dart';
import 'widgets/leave_decision_card.dart';

enum _Tab { pending, history }

/// The Admin's Leave tab (mock 03), shown by the `LeaveRequestsScreen`
/// placeholder: "n Pending" badge, Pending / History toggle and request
/// cards with Reject / Approve.
class LeaveManagementBody extends ConsumerStatefulWidget {
  const LeaveManagementBody({super.key});

  @override
  ConsumerState<LeaveManagementBody> createState() =>
      _LeaveManagementBodyState();
}

class _LeaveManagementBodyState extends ConsumerState<LeaveManagementBody> {
  _Tab _tab = _Tab.pending;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingLeaveForMeProvider);
    final decided = ref.watch(decidedLeaveForMeProvider);
    if (pending.hasError) {
      return ErrorState(
        message: "We couldn't load leave requests.",
        onRetry: () => ref.invalidate(approverLeaveRequestsProvider),
      );
    }
    final p = pending.value;
    final d = decided.value;
    if (p == null || d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final shown = _tab == _Tab.pending ? p : d;
    final people = {
      for (final r in [...p, ...d]) ...[r.userId, ?r.decidedBy],
    };
    final profiles =
        ref.watch(userProfilesProvider(profilesKey(people))).value ??
        const <String, AppUser>{};

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Header(pending: p.length),
            const SizedBox(height: 12),
            PillToggle<_Tab>(
              value: _tab,
              onChanged: (t) => setState(() => _tab = t),
              segments: [
                PillSegment(
                  value: _Tab.pending,
                  label: 'Pending (${p.length})',
                ),
                PillSegment(
                  value: _Tab.history,
                  label: 'History (${d.length})',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              _Empty(tab: _tab)
            else
              for (final (i, LeaveRequest r) in shown.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                LeaveDecisionCard(
                  key: ValueKey(r.id),
                  request: r,
                  profiles: profiles,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Leave',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (pending > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.appColors.chipBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$pending Pending',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.appColors.chipText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final _Tab tab;

  @override
  Widget build(BuildContext context) => tab == _Tab.pending
      ? const EmptyState(
          icon: Icons.event_available_outlined,
          title: 'No pending requests',
          message: 'Leave requests from your project members appear here.',
        )
      : const EmptyState(
          icon: Icons.history,
          title: 'No decisions yet',
          message: 'Requests you approve or reject are listed here.',
        );
}
