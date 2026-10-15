import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../application/password_policy.dart';

/// Strength bar plus the live rule checklist under the register screen's
/// password field (CLAUDE.md §9).
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.check});

  final PasswordCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final (double value, String label, Color color) = switch (check.strength) {
      PasswordStrength.empty => (0, '', theme.colorScheme.outlineVariant),
      PasswordStrength.weak => (0.25, 'Weak', theme.colorScheme.error),
      PasswordStrength.fair => (0.5, 'Fair', appColors.warning),
      PasswordStrength.good => (0.75, 'Good', appColors.success),
      PasswordStrength.strong => (1, 'Strong', appColors.success),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final rule in PasswordRule.values)
            _RuleRow(rule: rule, met: check.met.contains(rule)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.met});

  final PasswordRule rule;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = met
        ? theme.appColors.success
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rule.label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
