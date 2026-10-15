import 'package:flutter/material.dart';

/// Shared "coming soon" body for screens that are scaffolded in Phase 0 but
/// not yet functionally implemented.
class PlaceholderContent extends StatelessWidget {
  const PlaceholderContent({
    super.key,
    required this.icon,
    required this.message,
    this.child,
  });

  final IconData icon;
  final String message;

  /// Optional extra content (e.g. a demo button to a pushed detail route),
  /// shown below the placeholder message.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (child != null) ...[const SizedBox(height: 24), child!],
          ],
        ),
      ),
    );
  }
}
