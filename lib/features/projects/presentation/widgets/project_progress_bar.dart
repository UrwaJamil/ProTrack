import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// "Progress … 68%" with a bar below: accent fill, red when overdue.
class ProjectProgressBar extends StatelessWidget {
  const ProjectProgressBar({
    super.key,
    required this.progress,
    required this.overdue,
  });

  final int progress;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Progress', style: muted),
            const Spacer(),
            Text(
              '$progress%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: overdue ? colors.error : colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 6,
            color: overdue ? colors.error : theme.appColors.progressFill,
            backgroundColor: theme.appColors.progressTrack,
            semanticsLabel: 'Progress',
            semanticsValue: '$progress%',
          ),
        ),
      ],
    );
  }
}
