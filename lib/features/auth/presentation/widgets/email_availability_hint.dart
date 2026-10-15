import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/email_availability_controller.dart';

/// Inline feedback under the register screen's email field. Advisory only.
class EmailAvailabilityHint extends ConsumerWidget {
  const EmailAvailabilityHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(emailAvailabilityControllerProvider).status;
    final colors = Theme.of(context).colorScheme;

    final (IconData? icon, String? text, Color color) = switch (status) {
      EmailAvailabilityStatus.idle => (null, null, colors.onSurfaceVariant),
      EmailAvailabilityStatus.checking => (
        null,
        'Checking…',
        colors.onSurfaceVariant,
      ),
      EmailAvailabilityStatus.taken => (
        Icons.error_outline,
        'Email already in use',
        colors.error,
      ),
      EmailAvailabilityStatus.available => (
        Icons.check_circle_outline,
        'Available',
        Theme.of(context).appColors.success,
      ),
      EmailAvailabilityStatus.error => (
        Icons.cloud_off_outlined,
        "Couldn't check right now",
        colors.onSurfaceVariant,
      ),
    };
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Row(
        children: [
          if (status == EmailAvailabilityStatus.checking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
