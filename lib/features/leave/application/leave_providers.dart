import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/projects_providers.dart';
import '../data/leave_balance.dart';
import '../data/leave_repository.dart';
import '../data/leave_request.dart';
import '../data/leave_settings.dart';
import 'approvers.dart';

int _newestFirst(LeaveRequest a, LeaveRequest b) {
  final byStart = b.fromDate.compareTo(a.fromDate);
  return byStart != 0 ? byStart : b.createdAt.compareTo(a.createdAt);
}

/// The signed-in user's requests, latest leave first.
final myLeaveRequestsProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(leaveRepositoryProvider)
      .watchMine(uid)
      .map((list) => [...list]..sort(_newestFirst));
});

/// Requests the signed-in user is an approver of (pending and decided).
final approverLeaveRequestsProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(leaveRepositoryProvider).watchForApprover(uid);
});

/// Pending ones, oldest request first (first come, first decided).
final pendingLeaveForMeProvider = Provider<AsyncValue<List<LeaveRequest>>>(
  (ref) => ref
      .watch(approverLeaveRequestsProvider)
      .whenData(
        (list) =>
            list.where((r) => r.isPending).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      ),
);

/// Decided ones, most recent decision first.
final decidedLeaveForMeProvider = Provider<AsyncValue<List<LeaveRequest>>>(
  (ref) => ref
      .watch(approverLeaveRequestsProvider)
      .whenData(
        (list) => list.where((r) => !r.isPending).toList()
          ..sort(
            (a, b) => (b.decidedAt ?? b.createdAt).compareTo(
              a.decidedAt ?? a.createdAt,
            ),
          ),
      ),
);

/// One request, live; `null` once cancelled.
final leaveRequestProvider = StreamProvider.family<LeaveRequest?, String>(
  (ref, id) => ref.watch(leaveRepositoryProvider).watchRequest(id),
);

final leaveSettingsProvider = StreamProvider<LeaveSettings>(
  (ref) => ref.watch(leaveRepositoryProvider).watchSettings(),
);

/// Approved leave that hasn't ended yet (`leaveDays`).
final currentLeaveProvider = StreamProvider<List<LeaveDays>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(leaveRepositoryProvider).watchCurrentLeave(today);
});

/// Uids on approved leave today: the On Leave badge, computed on read
/// (CLAUDE.md decision 6). Empty while loading or if the query fails, so
/// a leave outage never hides people.
final onLeaveTodayProvider = Provider<Set<String>>((ref) {
  final today = ref.watch(todayProvider);
  final leave = ref.watch(currentLeaveProvider).value ?? const [];
  return {
    for (final l in leave)
      if (l.covers(today)) l.userId,
  };
});

/// The signed-in user's balance for the current year.
final myLeaveBalanceProvider = Provider<AsyncValue<LeaveBalance>>((ref) {
  final year = ref.watch(todayProvider).year;
  final requests = ref.watch(myLeaveRequestsProvider);
  final settings = ref.watch(leaveSettingsProvider);
  for (final a in [requests, settings]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  }
  final r = requests.value;
  final s = settings.value;
  if (r == null || s == null) return const AsyncLoading();
  return AsyncData(LeaveBalance.compute(requests: r, settings: s, year: year));
});

/// Who would approve the signed-in user's request ([approverIdsFor]).
final myApproverIdsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final uid = ref.watch(currentUidProvider) ?? '';
  return ref
      .watch(myProjectsProvider)
      .whenData((projects) => approverIdsFor(uid, projects));
});
