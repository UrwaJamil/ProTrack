import 'package:flutter/material.dart';

import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/pill_toggle.dart';
import '../../data/task.dart';
import '../../data/task_priority.dart';

/// Title, required work, deadline and priority (FR-3.1, FR-3.3), labels
/// above each field.
class TaskFormFields extends StatelessWidget {
  const TaskFormFields({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.deadline,
    required this.onDeadlineChanged,
    required this.priority,
    required this.onPriorityChanged,
    this.enabled = true,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final DateTime? deadline;
  final ValueChanged<DateTime> onDeadlineChanged;
  final TaskPriority priority;
  final ValueChanged<TaskPriority> onPriorityChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: 'Task title',
          child: TextFormField(
            controller: titleController,
            enabled: enabled,
            maxLength: taskTitleMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Design the login screen',
              prefixIcon: Icon(Icons.task_alt),
              counterText: '',
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter a task title'
                : null,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Required work',
          child: TextFormField(
            controller: descriptionController,
            enabled: enabled,
            minLines: 3,
            maxLines: 8,
            maxLength: taskDescriptionMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What needs to be done, and what "done" looks like',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LabeledField(
          label: 'Deadline',
          child: DateField(
            value: deadline,
            enabled: enabled,
            onChanged: onDeadlineChanged,
            initialPickerDate: DateTime.now().add(const Duration(days: 7)),
            validator: (d) => d == null ? 'Pick a deadline' : null,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Priority',
          child: PillToggle<TaskPriority>(
            value: priority,
            onChanged: enabled ? onPriorityChanged : (_) {},
            segments: [
              for (final p in TaskPriority.values)
                PillSegment(value: p, label: p.label, icon: Icons.flag),
            ],
          ),
        ),
      ],
    );
  }
}
