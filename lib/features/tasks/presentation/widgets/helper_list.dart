import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/state_views.dart';
import '../../application/helper_ranking.dart';
import 'helper_option_tile.dart';

/// "Who can help?": loading, error, empty ("no one else in the project")
/// or the ranked [HelperOptionTile]s as a single-choice list.
class HelperList extends StatelessWidget {
  const HelperList({
    super.key,
    required this.async,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
    this.enabled = true,
  });

  final AsyncValue<List<HelperCandidate>> async;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (async.hasError) {
      return SizedBox(
        height: 220,
        child: ErrorState(
          message: "We couldn't load your teammates.",
          onRetry: onRetry,
        ),
      );
    }
    final helpers = async.value;
    if (helpers == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (helpers.isEmpty) {
      return const EmptyState(
        icon: Icons.group_off_outlined,
        title: 'No one else in this project',
        message: 'You can still mark the task Blocked with a note.',
      );
    }
    return Column(
      children: [
        for (final h in helpers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HelperOptionTile(
              candidate: h,
              selected: h.user.uid == selectedId,
              onTap: enabled ? () => onSelect(h.user.uid) : null,
            ),
          ),
      ],
    );
  }
}
