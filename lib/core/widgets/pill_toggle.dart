import 'package:flutter/material.dart';

class PillSegment<T> {
  const PillSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;

  /// Shown on the selected side only.
  final IconData? icon;
}

/// Rounded two-or-more-way toggle (CLAUDE.md decision 10): the selected
/// side is a filled primary pill (plus its icon), the others plain text,
/// on a background-colored, outlined track.
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<PillSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                segment: segment,
                selected: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final PillSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;
    final radius = BorderRadius.circular(999);
    final icon = segment.icon;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected && icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      segment.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
