import 'package:flutter/material.dart';

import '../../data/leave_type.dart';

/// Leave type as a dropdown plus quick chips under it (mock 02); both
/// set the same value.
class LeaveTypePicker extends StatelessWidget {
  const LeaveTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LeaveType value;
  final ValueChanged<LeaveType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LeaveType>(
          initialValue: value,
          key: ValueKey(value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: [
            for (final t in LeaveType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) {
            if (t != null) onChanged(t);
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in LeaveType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: t == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(t),
              ),
          ],
        ),
      ],
    );
  }
}
