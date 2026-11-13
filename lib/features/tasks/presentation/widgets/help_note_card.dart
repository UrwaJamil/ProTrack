import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/help_note.dart';

/// The blocked task's help note, visible to everyone in the project
/// (Phase 4 "done when": Blocked note visible to Admin and team).
class HelpNoteCard extends StatelessWidget {
  const HelpNoteCard({super.key, required this.note, this.helperName});

  final HelpNote note;

  /// The tagged helper's name, if one was picked.
  final String? helperName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.statusBlockedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.statusBlockedText.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_outlined, color: c.statusBlockedText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helperName == null
                      ? 'Help requested'
                      : 'Help requested from $helperName',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: c.statusBlockedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(note.text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
