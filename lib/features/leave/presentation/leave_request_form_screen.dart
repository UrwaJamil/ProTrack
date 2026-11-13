import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../projects/application/projects_providers.dart';
import '../application/leave_providers.dart';
import 'widgets/leave_request_form.dart';

/// Request Leave (`/member/leave/new`, mock 02). Named
/// `LeaveRequestFormScreen` because `RequestLeaveScreen` is the Leave
/// tab's placeholder.
class LeaveRequestFormScreen extends ConsumerWidget {
  const LeaveRequestFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myLeaveBalanceProvider);
    final settings = ref.watch(leaveSettingsProvider);
    final approvers = ref.watch(myApproverIdsProvider);

    final Widget body;
    if (balance.hasError || settings.hasError || approvers.hasError) {
      body = ErrorState(
        message: "We couldn't load your leave balance.",
        onRetry: () {
          ref.invalidate(myLeaveRequestsProvider);
          ref.invalidate(leaveSettingsProvider);
          ref.invalidate(myProjectsProvider);
        },
      );
    } else if (balance.value == null ||
        settings.value == null ||
        approvers.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LeaveRequestForm(
            balance: balance.value!,
            settings: settings.value!,
            approverIds: approvers.value!,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Request Leave')),
      body: body,
    );
  }
}
