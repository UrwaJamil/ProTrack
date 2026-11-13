import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../application/leave_providers.dart';
import '../data/leave_balance.dart';
import '../data/leave_request.dart';
import 'leave_paths.dart';
import 'widgets/leave_request_tile.dart';
import 'widgets/leave_stat_tiles.dart';

/// The Member's Leave tab (mock 02), shown by the `RequestLeaveScreen`
/// placeholder: Used / Remaining / Pending, Request Leave, My requests.
class LeaveOverviewBody extends ConsumerWidget {
  const LeaveOverviewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myLeaveRequestsProvider);
    final balance = ref.watch(myLeaveBalanceProvider);
    if (requests.hasError || balance.hasError) {
      return ErrorState(
        message: "We couldn't load your leave.",
        onRetry: () {
          ref.invalidate(myLeaveRequestsProvider);
          ref.invalidate(leaveSettingsProvider);
        },
      );
    }
    final list = requests.value;
    final b = balance.value;
    if (list == null || b == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _Content(requests: list, balance: b);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.requests, required this.balance});

  final List<LeaveRequest> requests;
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            LeaveStatTiles(balance: balance),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.push(requestLeavePath),
                icon: const Icon(Icons.add),
                label: const Text('Request Leave'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My requests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${requests.length} total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (requests.isEmpty)
              const EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leave requests yet',
                message: 'Requests you send show up here with their status.',
              )
            else
              for (final (i, r) in requests.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                LeaveRequestTile(
                  request: r,
                  onOpen: () => context.push(leaveDetailPath(r.id)),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
