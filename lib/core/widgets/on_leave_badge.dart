import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// "On Leave": an outlined warning pill with an icon, so it doesn't rely
/// on color alone. Same shape as `StatusPill`, but its label can shrink
/// (ellipsis) so it never overflows a narrow row. Whether to show it comes
/// from the leave feature (`OnLeaveIndicator`), keeping this widget free
/// of feature imports.
class OnLeaveBadge extends StatelessWidget {
  const OnLeaveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.appColors.warning;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.beach_access_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'On Leave',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
