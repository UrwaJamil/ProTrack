import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../notifications/application/recipients.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../application/approvers.dart';
import '../../application/leave_validation.dart';
import '../../data/leave_balance.dart';
import '../../data/leave_repository.dart';
import '../../data/leave_request.dart';
import '../../data/leave_settings.dart';
import '../../data/leave_type.dart';
import '../../data/working_days.dart';
import 'balance_banner.dart';
import 'deadline_conflict_warning.dart';
import 'leave_type_picker.dart';

const maxLeaveReason = 500;

/// Request Leave (mock 02): balance banner, type, dates, reason, totals,
/// deadline-conflict warning, Submit Request. Blocks with a message when
/// over balance (never for "Other") or when nobody can approve.
class LeaveRequestForm extends ConsumerStatefulWidget {
  const LeaveRequestForm({
    super.key,
    required this.balance,
    required this.settings,
    required this.approverIds,
  });

  final LeaveBalance balance;
  final LeaveSettings settings;
  final List<String> approverIds;

  @override
  ConsumerState<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends ConsumerState<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  LeaveType _type = LeaveType.casual;
  DateTime? _from;
  DateTime? _to;
  bool _halfDay = false;
  bool _sending = false;

  bool get _singleDay =>
      _from != null && _to != null && dayOf(_from!) == dayOf(_to!);

  num get _working => _from == null || _to == null
      ? 0
      : workingDaysBetween(
          _from!,
          _to!,
          holidays: widget.settings.holidays,
          halfDay: _halfDay && _singleDay,
        );

  String? get _blocked => leaveBlockReason(
    approverIds: widget.approverIds,
    balance: widget.balance,
    type: _type,
    from: _from,
    to: _to,
    workingDays: _working,
  );

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _blocked != null) return;
    final uid = ref.read(currentUidProvider) ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _sending = true);
    try {
      final me = await ref.read(
        userProfilesProvider(profilesKey([uid])).future,
      );
      final projects = ref.read(myProjectsProvider).value ?? const [];
      await ref
          .read(leaveRepositoryProvider)
          .submit(
            LeaveDraft(
              type: _type,
              fromDate: _from!,
              toDate: _to!,
              halfDay: _halfDay && _singleDay,
              reason: _reason.text,
              workingDays: _working,
            ),
            userId: uid,
            approverIds: widget.approverIds,
            notify: approverProjects(uid, widget.approverIds, projects),
            requesterName: me[uid]?.name ?? 'A teammate',
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Leave request sent for approval.')),
      );
      if (router.canPop()) router.pop();
    } on LeaveNotifyException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Leave request sent, but approvers couldn't be notified.",
          ),
        ),
      );
      if (router.canPop()) router.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't send the request. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    final uid = ref.watch(currentUidProvider) ?? '';
    final conflicts = _from == null || _to == null
        ? const []
        : tasksDueDuring(
            (ref.watch(myTasksProvider).value ?? const []).map((e) => e.task),
            uid: uid,
            from: _from!,
            to: _to!,
          );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          BalanceBanner(
            type: _type,
            available: widget.balance.availableFor(_type),
            year: ref.watch(todayProvider).year,
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Leave type',
            child: LeaveTypePicker(
              value: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
          ),
          const SizedBox(height: 16),
          _DateRow(
            from: _from,
            to: _to,
            onFrom: (d) => setState(() {
              _from = d;
              if (_to == null || dayOf(_to!).isBefore(d)) _to = d;
            }),
            onTo: (d) => setState(() => _to = d),
          ),
          if (_singleDay)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Half day'),
              value: _halfDay,
              onChanged: (v) => setState(() => _halfDay = v),
            ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Reason',
            child: TextFormField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: maxLeaveReason,
              decoration: const InputDecoration(
                hintText: 'Briefly, why you need leave',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Please add a reason.' : null,
            ),
          ),
          _Totals(
            total: _from == null || _to == null
                ? 0
                : calendarDaysBetween(_from!, _to!),
            working: _working,
          ),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DeadlineConflictWarning(tasks: [...conflicts]),
          ],
          _SubmitSection(blocked: blocked, busy: _sending, onSubmit: _submit),
        ],
      ),
    );
  }
}

/// The blocking message (if any), Submit Request and the approval
/// caption.
class _SubmitSection extends StatelessWidget {
  const _SubmitSection({
    required this.blocked,
    required this.busy,
    required this.onSubmit,
  });

  final String? blocked;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final message = blocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message,
            key: const ValueKey('leave-blocked'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Submit Request',
          busy: busy,
          onPressed: message == null ? onSubmit : null,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 14, color: muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Approval typically arrives within 24 hours',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
  });

  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;

  @override
  Widget build(BuildContext context) {
    String? required(DateTime? d) => d == null ? 'Pick a date.' : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledField(
            label: 'Start date',
            child: DateField(
              value: from,
              hint: 'Start',
              onChanged: onFrom,
              validator: required,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LabeledField(
            label: 'End date',
            child: DateField(
              value: to,
              hint: 'End',
              initialPickerDate: from,
              onChanged: onTo,
              validator: required,
            ),
          ),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.total, required this.working});

  final int total;
  final num working;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Total days: $total',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          workingDaysLabel(working),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
